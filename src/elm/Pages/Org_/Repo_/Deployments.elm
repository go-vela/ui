{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Deployments exposing (..)

import Api.Pagination
import Auth
import Components.Pager
import Components.Svgs as SvgBuilder
import Components.Table
import Dict
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , div
        , span
        , td
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , href
        , rows
        , scope
        )
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import List
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg.Attributes
import Time
import Url
import Utils.Errors
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Repo
        { navButtons = []
        , utilButtons = []
        , org = route.params.org
        , repo = route.params.repo
        }



-- INIT


type alias Model =
    { deployments : WebData (List Vela.Deployment)
    , pager : List WebLink
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { deployments = RemoteData.Loading
      , pager = []
      }
    , Effect.getRepoDeployments
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetRepoDeploymentsResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = -- DEPLOYMENTS
      GetRepoDeploymentsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Deployment ))
    | GotoPage Int
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- DEPLOYMENTS
        GetRepoDeploymentsResponse response ->
            case response of
                Ok ( meta, deployments ) ->
                    ( { model
                        | deployments = RemoteData.Success deployments
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | deployments = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.replaceRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getRepoDeployments
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetRepoDeploymentsResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getRepoDeployments
                { baseUrl = shared.velaAPI
                , session = shared.session
                , onResponse = GetRepoDeploymentsResponse
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                , org = route.params.org
                , repo = route.params.repo
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Deployments"
    , body =
        [ viewDeployments model route.params.org route.params.repo model.deployments
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        ]
    }


{-| viewDeployments : renders a list of deployments
-}
viewDeployments : Model -> String -> String -> WebData (List Vela.Deployment) -> Html Msg
viewDeployments model org repo deployments =
    let
        actions =
            Just <|
                div [ class "buttons" ]
                    [ a
                        [ class "button"
                        , class "-outline"
                        , class "button-with-icon"
                        , Util.testAttribute "add-deployment"
                        , Route.Path.href <|
                            Route.Path.Org_Repo_DeploymentsAdd { org = org, repo = repo }
                        ]
                        [ text "Add Deployment"
                        , FeatherIcons.plus
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                        ]
                    , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
                    ]

        ( noRowsView, rows ) =
            case deployments of
                RemoteData.Success d ->
                    ( text "No deployments found for this repo"
                    , deploymentsToRows org repo d
                    )

                RemoteData.Failure error ->
                    ( span [ Util.testAttribute "repo-deployments-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No deployments found for this repo, most likely due to not having access to the source control repo"

                                        _ ->
                                            "No deployments found for this repo, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No deployments found for this repo, there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( Util.largeLoader, [] )

        cfg =
            Components.Table.Config
                "Deployments"
                "deployments"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div []
        [ Components.Table.view cfg
        ]



-- TABLE


{-| deploymentsToRows : takes list of deployments and produces list of Table rows
-}
deploymentsToRows : String -> String -> List Vela.Deployment -> Components.Table.Rows Vela.Deployment Msg
deploymentsToRows org repo deployments =
    List.map (\deployment -> Components.Table.Row deployment (renderDeployment org repo)) deployments


{-| tableHeaders : returns table headers for deployments table
-}
tableHeaders : Components.Table.Columns
tableHeaders =
    [ ( Just "-icon", "" )
    , ( Nothing, "number" )
    , ( Nothing, "target" )
    , ( Nothing, "commit" )
    , ( Nothing, "ref" )
    , ( Nothing, "description" )
    , ( Nothing, "user" )
    , ( Nothing, "" )
    ]


{-| renderDeployment : takes deployment and renders a table row
-}
renderDeployment : String -> String -> Vela.Deployment -> Html Msg
renderDeployment org repo deployment =
    let
        -- todo: somehow build the repo clone link and append the commit hash
        -- Util.buildRepoCloneLink org repo
        repoCloneLink =
            ""
    in
    tr [ Util.testAttribute <| "deployments-row" ]
        [ td
            [ attribute "data-label" ""
            , scope "row"
            , class "break-word"
            , class "-icon"
            ]
            [ SvgBuilder.hookSuccess ]
        , td
            [ attribute "data-label" "id"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "deployments-row-id"
            ]
            [ text <| String.fromInt deployment.id ]
        , td
            [ attribute "data-label" "target"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "deployments-row-target"
            ]
            [ text deployment.target ]
        , td
            [ attribute "data-label" "commit"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "deployments-row-commit"
            ]
            [ a [ href <| Util.buildRefURL repoCloneLink deployment.commit ]
                [ text <| Util.trimCommitHash deployment.commit ]
            ]
        , td
            [ attribute "data-label" "ref"
            , scope "row"
            , class "break-word"
            , class "ref"
            , Util.testAttribute <| "deployments-row-ref"
            ]
            [ span [ class "list-item" ] [ text <| deployment.ref ] ]
        , td
            [ attribute "data-label" "description"
            , scope "row"
            , class "break-word"
            , class "description"
            ]
            [ text deployment.description ]
        , td
            [ attribute "data-label" "user"
            , scope "row"
            , class "break-word"
            ]
            [ text deployment.user ]
        , td
            [ attribute "data-label" ""
            , scope "row"
            , class "break-word"
            ]
            [ redeployLink org repo deployment ]
        ]


{-| redeployLink : takes org, repo and deployment and renders a link to redirect to the promote deployment page
-}
redeployLink : String -> String -> Vela.Deployment -> Html Msg
redeployLink org repo deployment =
    a
        [ class "redeploy-link"
        , attribute "aria-label" <| "redeploy deployment " ++ String.fromInt deployment.id
        , Route.href <|
            { path = Route.Path.Org_Repo_DeploymentsAdd { org = org, repo = repo }
            , query =
                Dict.fromList <|
                    [ ( "target", deployment.target )
                    , ( "ref", deployment.ref )
                    , ( "description", deployment.description )
                    , ( "task", deployment.task )
                    ]
                        ++ Maybe.Extra.unwrap
                            []
                            (\parameters ->
                                [ ( "parameters"
                                  , String.join ","
                                        (List.map
                                            (\parameter ->
                                                Url.percentEncode <| parameter.key ++ "=" ++ parameter.value
                                            )
                                            parameters
                                        )
                                  )
                                ]
                            )
                            deployment.payload
            , hash = Nothing
            }
        , Util.testAttribute "redeploy-deployment"
        ]
        [ text "Redeploy"
        ]
