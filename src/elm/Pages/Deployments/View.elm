{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.View exposing (addDeployment, addForm, promoteDeployment, viewDeployments)

import Errors exposing (viewResourceError)
import FeatherIcons
import Html exposing (Html, a, div, h2, p, strong, text)
import Html.Attributes exposing (class)
import Pages.Deployments.Form exposing (viewDeployEnabled, viewHelp, viewParameterInput, viewSubmitButtons, viewValueInput)
import Pages.Deployments.Model
    exposing
        ( Model
        , Msg(..)
        , PartialModel
        )
import RemoteData exposing (RemoteData(..))
import Routes
import Svg exposing (svg)
import Svg.Attributes exposing (d, height, strokeWidth, viewBox, width)
import SvgBuilder exposing (buildStatusToIcon)
import Time exposing (Posix, Zone)
import Util exposing (ariaHidden, largeLoader)
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
        , viewSubmitButtons deploymentModel
        ]


{-| viewPreview : renders single deployment item preview
-}
viewPreview : Org -> Repo -> Deployment -> Html msg
viewPreview org repo deployment =
    let
        deploymentId =
            String.fromInt deployment.id

        -- deploymentDetails =
        --     div [ class "deployment-details" ]
        --         [ p [] [ text (" Task: " ++ deployment.task) ]
        --         , p [] [ text (" Ref: " ++ deployment.ref) ]
        --         , p [] [ text <| " Description: " ++ deployment.description ]
        --         ]

        markdown =
            [ div [ class "status", Util.testAttribute "build-status", class "-success" ]
                [ buildStatusToIcon Vela.Success ]
            , div [ class "info" ]
                [ div [ class "row -left" ]
                    [ div [ class "id" ] [ text ("#" ++ deploymentId) ]
                    , div [ class "commit-msg" ] [ strong [] [ text deployment.description ] ]
                    ]
                , div [ class "row" ]
                    [ div [ class "git-info" ]
                        [ div [ class "commit" ] [ text deployment.commit ]
                        , text "on"
                        , div [ class "branch" ] [ text deployment.ref ]
                        , text "by"
                        , div [ class "sender" ] [ text deployment.user ]
                        ]
                ]
                , div []
                    [ p [] [ text (deployment.target ++ " at (" ++ Util.trimCommitHash deployment.commit ++ ")") ]
                    , p [] [ text (" Deployed by " ++ deployment.user) ]
                    ]
                ]

            --, deploymentDetails
            , div [ class "deployment-link" ] [ a [ Routes.href <| Routes.PromoteDeployment org repo deploymentId ] [ text "Deploy" ] ]
            ]
    in
    div [ class "build-container", Util.testAttribute "deployment" ]
        [ div [ class "build" ] <|
            markdown
        ]


{-| viewDeployments : renders a list of deployments
-}
viewDeployments : DeploymentsModel -> Posix -> Zone -> Org -> Repo -> Html msg
viewDeployments deploymentsModel now zone org repo =
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

        none : Html msg
        none =
            div []
                [ div [ class "buttons", class "add-deployment-buttons" ] [ text "", addButton ]
                , h2 [] [ text "No deployments found." ]
                ]
    in
    case deploymentsModel.deployments of
        RemoteData.Success deployments ->
            if List.length deployments == 0 then
                none

            else
                let
                    deploymentList =
                        div [ class "deployments", Util.testAttribute "deployments" ] <| List.map (viewPreview org repo) deployments
                in
                div []
                    [ div [ class "buttons", class "add-deployment-buttons" ] [ text "", addButton ]
                    , deploymentList
                    ]

        RemoteData.Loading ->
            largeLoader

        RemoteData.NotAsked ->
            largeLoader

        RemoteData.Failure _ ->
            viewResourceError { resourceLabel = "deployments for this repository", testLabel = "deployments" }



-- Promote Deployment


{-| promoteDeployment : takes partial model and renders deployment form for promoting a deployment
-}
promoteDeployment : PartialModel a msg -> Html Msg
promoteDeployment model =
    div [ class "manage-deployment", Util.testAttribute "add-deployment" ]
        [ div []
            [ addForm model.deploymentModel
            ]
        ]
