{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Deployments_ exposing (..)

import Api.Pagination
import Auth
import Components.Svgs as SvgBuilder
import Components.Table as Table
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
import List
import Page exposing (Page)
import Pager
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Routes
import Shared
import Svg.Attributes
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela exposing (Deployment, Org, Repo, Repository)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update
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
        , nil = []
        }



-- INIT


type alias Model =
    { deployments : WebData (List Vela.Deployment)
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { deployments = RemoteData.Loading
      }
    , Effect.getRepoDeployments
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetRepoDeploymentsResponse
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = GetRepoDeploymentsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Deployment ))


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        GetRepoDeploymentsResponse response ->
            case response of
                Ok ( _, deployments ) ->
                    ( { model | deployments = RemoteData.Success deployments }
                    , Effect.none
                    )

                Err error ->
                    ( { model | deployments = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    let
        cloneUrlChangeMe =
            ""

        table =
            viewDeployments route.params.org route.params.repo cloneUrlChangeMe model.deployments
    in
    { title = "Pages.Org_.Repo_.Deployments_"
    , body =
        [ table

        -- , Pager.view shared.repo.deployments.pager Pager.defaultLabels GotoPage
        ]
    }


{-| viewDeployments : renders a list of deployments
-}
viewDeployments : String -> String -> String -> WebData (List Vela.Deployment) -> Html Msg
viewDeployments org repo clone deployments =
    let
        addButton =
            a
                [ class "button"
                , class "-outline"
                , class "button-with-icon"
                , Util.testAttribute "add-deployment"
                , Routes.href <|
                    Routes.AddDeploymentRoute org repo
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
                    , deploymentsToRows org repo clone d
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
            Table.Config
                "Deployments"
                "deployments"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div []
        [ Table.view cfg
        ]



-- TABLE


{-| deploymentsToRows : takes list of deployments and produces list of Table rows
-}
deploymentsToRows : String -> String -> String -> List Deployment -> Table.Rows Deployment Msg
deploymentsToRows org repo clone deployments =
    List.map (\deployment -> Table.Row deployment (renderDeployment org repo clone)) deployments


{-| tableHeaders : returns table headers for deployments table
-}
tableHeaders : Table.Columns
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
renderDeployment : String -> String -> String -> Deployment -> Html Msg
renderDeployment org repo clone deployment =
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
            [ a [ href <| Util.buildRefURL clone deployment.commit ]
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
redeployLink : Org -> Repo -> Deployment -> Html Msg
redeployLink org repo deployment =
    a
        [ class "redeploy-link"
        , attribute "aria-label" <| "redeploy deployment " ++ String.fromInt deployment.id
        , Routes.href <| Routes.PromoteDeployment org repo (String.fromInt deployment.id)
        , Util.testAttribute "redeploy-deployment"
        ]
        [ text "Redeploy"
        ]
