{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Deployments.View exposing (addDeployment, viewDeployments)

import FeatherIcons
import Html exposing (Html, a, div, h2, span, td, text, tr)
import Html.Attributes exposing (attribute, class, href, scope)
import Http
import Pages.Deployments.Form exposing (viewDeployEnabled, viewHelp, viewParameterInput, viewSubmitButtons, viewValueInput)
import Pages.Deployments.Model
    exposing
        ( Model
        , Msg
        , PartialModel
        )
import RemoteData
import Routes
import Svg.Attributes
import SvgBuilder exposing (hookSuccess)
import Table
import Time exposing (Zone)
import Util exposing (largeLoader)
import Vela exposing (Deployment, Org, Repo, RepoModel, Repository)



-- ADD DEPLOYMENT


{-| addDeployment : takes partial model and renders the Add Deployment form
-}
addDeployment : PartialModel a msg -> Html Msg
addDeployment model =
    div [ class "manage-deployment", Util.testAttribute "add-deployment" ]
        [ div []
            [ addForm model.deploymentModel
            ]
        ]


{-| addForm : renders deployment form for adding a new deployment
-}
addForm : Model msg -> Html Msg
addForm deploymentModel =
    let
        deployment =
            deploymentModel.form

        branch =
            case deploymentModel.repo_settings of
                RemoteData.Success repo ->
                    repo.branch

                _ ->
                    ""
    in
    div [ class "deployment-form" ]
        [ h2 [ class "deployment-header" ] [ text "Add Deployment" ]
        , viewDeployEnabled deploymentModel.repo_settings

        -- GitHub default is "production". If we support more SCMs, this line may need tweaking
        , viewValueInput "Target" deployment.target "provide the name for the target deployment environment (default: \"production\")"
        , viewValueInput "Ref" deployment.ref <| "provide the reference to deploy - this can be a branch, commit (SHA) or tag (default: " ++ branch ++ ")"
        , viewValueInput "Description" deployment.description "provide the description for the deployment (default: \"Deployment request from Vela\")"
        , viewValueInput "Task" deployment.task "Provide the task for the deployment (default: \"deploy:vela\")"
        , viewParameterInput deployment
        , viewHelp
        , viewSubmitButtons
        ]


{-| viewDeployments : renders a list of deployments
-}
viewDeployments : Zone -> RepoModel -> Org -> Repo -> Html msg
viewDeployments zone repoModel org repo =
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
            case ( repoModel.repo, repoModel.deployments.deployments ) of
                ( RemoteData.Success repo_, RemoteData.Success s ) ->
                    ( text "No deployments found for this repo"
                    , deploymentsToRows zone repo_ s
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
                    ( largeLoader, [] )

        cfg =
            Table.Config
                "Deployments"
                "deployments"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div [] [ Table.view cfg ]



-- TABLE


{-| deploymentsToRows : takes list of deployments and produces list of Table rows
-}
deploymentsToRows : Zone -> Repository -> List Deployment -> Table.Rows Deployment msg
deploymentsToRows zone repo_ deployments =
    List.map (\deployment -> Table.Row deployment (renderDeployment zone repo_)) deployments


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
    , ( Nothing, "builds" )
    , ( Nothing, "created by" )
    , ( Nothing, "created at" )
    , ( Nothing, "" )
    ]


{-| renderDeployment : takes deployment and renders a table row
-}
renderDeployment : Zone -> Repository -> Deployment -> Html msg
renderDeployment zone repo_ deployment =
    tr [ Util.testAttribute <| "deployments-row" ]
        [ td
            [ attribute "data-label" ""
            , scope "row"
            , class "break-word"
            , class "-icon"
            ]
            [ hookSuccess ]
        , td
            [ attribute "data-label" "number"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "deployments-row-number"
            ]
            [ text <| String.fromInt deployment.number ]
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
            [ attribute "data-label" "builds"
            , scope "row"
            , class "break-word"
            , class "build"
            ]
            [ linksView (pullBuildLinks deployment) ]
        , td
            [ attribute "data-label" "created by"
            , scope "row"
            , class "break-word"
            ]
            [ text deployment.created_by ]
        , td
            [ attribute "data-label" "created at"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.humanReadableDateTimeWithDefault zone deployment.created_at ]
        , td
            [ attribute "data-label" ""
            , scope "row"
            , class "break-word"
            ]
            [ redeployLink repo_.org repo_.name deployment ]
        ]


{-| redeployLink : takes org, repo and deployment and renders a link to redirect to the promote deployment page
-}
redeployLink : Org -> Repo -> Deployment -> Html msg
redeployLink org repo deployment =
    a
        [ class "redeploy-link"
        , attribute "aria-label" <| "redeploy deployment " ++ String.fromInt deployment.id
        , Routes.href <| Routes.PromoteDeployment org repo (String.fromInt deployment.id)
        , Util.testAttribute "redeploy-deployment"
        ]
        [ text "Redeploy"
        ]


{-| pullBuildLinks : takes deployment and creates a list of links to every build in the builds field
-}
pullBuildLinks : Deployment -> List String
pullBuildLinks deployment =
    case deployment.builds of
        Nothing ->
            []

        Just builds ->
            List.map .link builds


{-| linksView : takes list of links and creates an HTML msg that displays as a list of links
-}
linksView : List String -> Html msg
linksView links =
    links
        |> List.map
            (\link ->
                a
                    [ href link ]
                    [ text
                        (link
                            |> String.split "/"
                            |> List.reverse
                            |> List.head
                            |> Maybe.withDefault ""
                            |> String.append "#"
                        )
                    ]
            )
        |> List.intersperse (text ", ")
        |> div []
