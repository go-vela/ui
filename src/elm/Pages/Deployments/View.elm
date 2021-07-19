{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.View exposing (addDeployment, addForm, viewDeployments, promoteDeployment)

import Errors exposing (viewResourceError)
import Html exposing (Html, div, h2, text)
import Html
    exposing
        ( Html
        , a
        , br
        , code
        , div
        , em
        , h1
        , li
        , ol
        , p
        , text
        )
import Html.Attributes exposing (class, href)
import Http.Extras exposing (State(..))
import Pages.Build.View exposing (viewPreview)
import Pages.Deployments.Form exposing (viewDeployEnabled, viewHelp, viewParameterInput, viewSubmitButtons, viewValueInput)
import Pages.Deployments.Model
    exposing
        ( Model
        , Msg(..)
        , PartialModel
        )
import Pages.Deployments.Update exposing (initializeFormFromDeployment)
import RemoteData exposing (RemoteData(..))
import Util exposing (largeLoader, testAttribute)
import Time exposing (Posix, Zone)
import Vela exposing (BuildsModel, Event, Org, Repo)



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

viewDeployments : BuildsModel -> Posix -> Zone -> Org -> Repo -> Maybe Event -> Html msg
viewDeployments buildsModel now zone org repo maybeEvent =
                    let
                        none : Html msg
                        none =
                            case maybeEvent of
                                Nothing ->
                                    div [] []
                                    -- Maybe Event will always be "deployment" for this component

                                Just _ ->
                                    div []
                                        [ h1 [] [ text <| "No deployments found." ] ]
                    in
                    case buildsModel.builds of
                        RemoteData.Success builds ->
                            if List.length builds == 0 then
                                none

                            else
                                div [ class "builds", Util.testAttribute "builds" ] <| List.map (viewPreview now zone org repo) builds

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
