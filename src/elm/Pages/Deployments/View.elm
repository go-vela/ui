{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.View exposing (addDeployment, addForm, promoteDeployment, viewDeployments)

import Errors exposing (viewResourceError)
import FeatherIcons
import Html exposing (Html, a, br, code, div, em, h1, h2, li, ol, p, strong, text)
import Html.Attributes exposing (class, href)
import Pages.Deployments.Form exposing (viewDeployEnabled, viewHelp, viewParameterInput, viewSubmitButtons, viewValueInput)
import Pages.Deployments.Model
    exposing
        ( Model
        , Msg(..)
        , PartialModel
        )
import RemoteData exposing (RemoteData(..))
import Routes
import Svg.Attributes
import Time exposing (Posix, Zone)
import Util exposing (largeLoader, testAttribute)
import Vela exposing (BuildsModel, Deployment, DeploymentsModel, Event, Org, Repo)



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

{-| viewPreview : renders single build item preview based on current application time
-}
viewPreview : Org -> Repo -> Deployment -> Html msg
viewPreview org repo deployment =
    let
        deploymentId =
            String.fromInt deployment.id

        commit =
            [ text "deployment"
            , text " ("
            , a [ href deployment.ref ] [ text <| Util.trimCommitHash deployment.commit ]
            , text <| ")"
            ]

        sender =
            [ text deployment.target ]

        message =
            [ text <| "- " ++ deployment.description ]

        promoteDeploymentLink =
             a [ Routes.href <| Routes.PromoteDeployment org repo deploymentId ] [ text "Promote" ]


        markdown =
            [ div [ class "info" ] [
                div [ class "row -left" ] [
                    div [ class "id" ] [
                        text deploymentId
                        , div [ class "commit-msg" ] [
                            strong [] message ]
                        ]
                        , div [ class "row" ] [
                            div [ class "git-info" ] [
                                div [ class "commit" ]
                                commit
                                , text "on"
                                , text "by"
                                , div [ class "sender" ]
                                    sender
                                    , promoteDeploymentLink
                                    ]
                                ]
                            ]
                        ]
                    ]

    in
    div [ class "build-container", Util.testAttribute "build" ]
        [ div [ class "build" ] <|
            markdown
        ]

viewDeployments : DeploymentsModel -> Posix -> Zone -> Org -> Repo -> Maybe Event -> Html msg
viewDeployments deploymentsModel now zone org repo maybeEvent =
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
            case maybeEvent of
                Nothing ->
                    div [] []

                -- Maybe Event will always be "deployment" for this component
                Just _ ->
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
                        div [ class "builds", Util.testAttribute "builds" ] <| List.map (viewPreview org repo) deployments
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


{-| editSecret : takes partial model and renders secret update form for editing a secret
-}
promoteDeployment : PartialModel a msg -> Html Msg
promoteDeployment model =
    div [ class "manage-deployment", Util.testAttribute "add-deployment" ]
        [ div []
            [ addForm model.deploymentModel
            ]
        ]
