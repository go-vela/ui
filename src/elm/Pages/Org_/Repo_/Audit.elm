{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Audit exposing (..)

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
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Svg.Attributes
import Utils.Errors as Errors
import Utils.Helpers as Util
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
        { org = route.params.org
        , repo = route.params.repo
        , navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { hooks : WebData (List Vela.Hook)
    , pager : List WebLink
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { hooks = RemoteData.Loading
      , pager = []
      }
    , Effect.getRepoHooks
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetRepoHooksResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = GetRepoHooksResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Hook ))
    | GotoPage Int


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetRepoHooksResponse response ->
            case response of
                Ok ( meta, hooks ) ->
                    ( { model
                        | hooks = RemoteData.Success hooks
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | hooks = Errors.toFailure error }
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
                , Effect.getRepoHooks
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetRepoHooksResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = route.params.org ++ "/" ++ route.params.repo ++ " Hooks"
    , body =
        [ --      viewDeployments route.params.org route.params.repo model.hooks
          -- ,
          text "hooks"
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        ]
    }


{-| viewDeployments : renders a list of deployments
-}
viewDeployments : String -> String -> WebData (List Vela.Deployment) -> Html Msg
viewDeployments org repo deployments =
    let
        addButton =
            a
                [ class "button"
                , class "-outline"
                , class "button-with-icon"
                , Util.testAttribute "add-deployment"

                -- todo: need add deployment path to do this
                -- , Route.Path.href <|
                --     Route.Path.Org_Repo_Deployments { org = org, repo = repo }
                ]
                [ text "Add Deployment"
                , FeatherIcons.plus
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                ]

        actions =
            Just <|
                div [ class "buttons" ]
                    [ addButton
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

        -- todo: need add deployment path to do this
        -- , Routes.href <| Routes.PromoteDeployment org repo (String.fromInt deployment.id)
        -- , Route.Path.href <|
        --     Route.Path.Org_Repo_Deployments { org = org, repo = repo }
        , Util.testAttribute "redeploy-deployment"
        ]
        [ text "Redeploy"
        ]
