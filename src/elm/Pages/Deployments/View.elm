{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.View exposing (addDeployment, viewDeployments)

import FeatherIcons
import Html exposing (Html, a, div, h2, span, td, text, tr)
import Html.Attributes exposing (attribute, class, scope)
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
import Util exposing (largeLoader)
import Vela exposing (Deployment, DeploymentsModel, Org, Repo)



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
    in
    div [ class "deployment-form" ]
        [ h2 [ class "deployment-header" ] [ text "Add Deployment" ]
        , viewDeployEnabled deploymentModel.repo_settings
        , viewValueInput "Target" deployment.target "provide the name for the target deployment environment (default: \"production\")"
        , viewValueInput "Ref" deployment.ref "provide the reference to deploy - this can be a branch, commit (SHA) or tag (default: \"refs/heads/master\")"
        , viewValueInput "Description" deployment.description "provide the description for the deployment (default: \"Deployment request from Vela\")"
        , viewValueInput "Task" deployment.task "Provide the task for the deployment (default: \"deploy:vela\")"
        , viewParameterInput deployment
        , viewHelp
        , viewSubmitButtons
        ]


{-| viewDeployments : renders a list of deployments
-}
viewDeployments : DeploymentsModel -> Org -> Repo -> Html msg
viewDeployments deploymentsModel org repo =
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
            case deploymentsModel.deployments of
                RemoteData.Success s ->
                    ( text "No deployments found for this repo"
                    , deploymentsToRows org repo s
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
deploymentsToRows : Org -> Repo -> List Deployment -> Table.Rows Deployment msg
deploymentsToRows org repo deployments =
    List.map (\deployment -> Table.Row deployment (renderDeployment org repo)) deployments


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
    , ( Just "-icon", "" )
    ]


{-| renderDeployment : takes deployment and renders a table row
-}
renderDeployment : Org -> Repo -> Deployment -> Html msg
renderDeployment org repo deployment =
    tr [ Util.testAttribute <| "deployments-row" ]
        [ td
            [ attribute "data-label" "deployment-icon"
            , scope "row"
            , class "break-word"
            , class "-icon"
            ]
            [ hookSuccess ]
        , td
            [ attribute "data-label" ""
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
            [ a [] [ text <| Util.trimCommitHash deployment.commit ] ]
        , td
            [ attribute "data-label" "ref"
            , scope "row"
            , class "break-word"
            , class "ref"
            , Util.testAttribute <| "deployments-row-ref"
            ]
            [ text <| deployment.ref ]
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
            [ attribute "data-label" "redeploy"
            , scope "row"
            , class "break-word"
            ]
            [ redeployButton org repo deployment ]
        ]


{-| redeployButton : takes org, repo and deployment and renders a button to redirect to the promote deployment page
-}
redeployButton : Org -> Repo -> Deployment -> Html msg
redeployButton org repo deployment =
    a
        [ class "copy-button"
        , attribute "aria-label" <| "redeploy deployment " ++ String.fromInt deployment.id
        , class "button"
        , class "-icon"
        , Routes.href <| Routes.PromoteDeployment org repo (String.fromInt deployment.id)
        , Util.testAttribute "copy-hook"
        ]
        [ FeatherIcons.repeat
            |> FeatherIcons.withSize 18
            |> FeatherIcons.toHtml []
        ]
