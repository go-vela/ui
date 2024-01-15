module Pages.Org_.Repo_.Deployments_ exposing (..)

import Api.Pagination
import Auth
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
import Html.Events
import Http
import Layouts
import List
import Page exposing (Page)
import Pager
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Routes
import Shared
import Shared.Msg
import Svg.Attributes
import SvgBuilder
import Table
import Util
import Vela exposing (Deployment, Org, Repo, Repository)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view shared
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default
        { navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    let
        _ =
            Debug.log "Pages.Org_.Repo_.Deployments_.init" ""
    in
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp
    | GotoPage Api.Pagination.Page


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        GotoPage pageNumber ->
            ( model
            , Effect.gotoPage { pageNumber = pageNumber }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes current user, user input and action params and renders home page with favorited repos
-}
view : Shared.Model -> Model -> View Msg
view shared model =
    let
        table =
            viewDeployments shared.repo
    in
    { title = "Pages.Org_.Repo_.Deployments_"
    , body =
        [ table
        , Pager.view shared.repo.deployments.pager Pager.defaultLabels GotoPage
        ]
    }


{-| viewDeployments : renders a list of deployments
-}
viewDeployments : Vela.RepoModel -> Html Msg
viewDeployments repo =
    let
        addButton =
            a
                [ class "button"
                , class "-outline"
                , class "button-with-icon"
                , Util.testAttribute "add-deployment"
                , Routes.href <|
                    Routes.AddDeploymentRoute repo.org repo.name
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
            case ( repo.repo, repo.deployments.deployments ) of
                ( RemoteData.Success repo_, RemoteData.Success s ) ->
                    ( text "No deployments found for this repo"
                    , deploymentsToRows repo_ s
                    )

                ( _, RemoteData.Failure error ) ->
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

                ( RemoteData.Failure error, _ ) ->
                    ( span [ Util.testAttribute "repo-deployments-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No repo found, most likely due to not having access to the source control provider"

                                        _ ->
                                            "No repo found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

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
deploymentsToRows : Repository -> List Deployment -> Table.Rows Deployment Msg
deploymentsToRows repo_ deployments =
    List.map (\deployment -> Table.Row deployment (renderDeployment repo_)) deployments


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
renderDeployment : Repository -> Deployment -> Html Msg
renderDeployment repo_ deployment =
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
            [ a [ href <| Util.buildRefURL repo_.clone deployment.commit ]
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
            [ redeployLink repo_.org repo_.name deployment ]
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
