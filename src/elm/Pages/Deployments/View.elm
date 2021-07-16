{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.View exposing (addDeployment, addForm, viewDeployments)

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
import Pages.Build.View exposing (viewPreview)
import Pages.Deployments.Form exposing (viewDeployEnabled, viewHelp, viewParameterInput, viewSubmitButtons, viewValueInput)
import Pages.Deployments.Model
    exposing
        ( Model
        , Msg(..)
        , PartialModel
        )
import RemoteData
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
                        settingsLink : String
                        settingsLink =
                            "/" ++ String.join "/" [ org, repo ] ++ "/settings"

                        none : Html msg
                        none =
                            case maybeEvent of
                                Nothing ->
                                    div []
                                        [ p [] [ text "Builds will show up here once you have:" ]
                                        , ol [ class "list" ]
                                            [ li []
                                                [ text "A "
                                                , code [] [ text ".vela.yml" ]
                                                , text " file that describes your build pipeline in the root of your repository."
                                                , br [] []
                                                , a [ href "https://go-vela.github.io/docs/usage/" ] [ text "Review the documentation" ]
                                                , text " for help or "
                                                , a [ href "https://go-vela.github.io/docs/usage/examples/" ] [ text "check some of the pipeline examples" ]
                                                , text "."
                                                ]
                                            , li []
                                                [ text "Trigger one of the "
                                                , a [ href settingsLink ] [ text "configured webhook events" ]
                                                , text " by performing the respective action via "
                                                , em [] [ text "Git" ]
                                                , text "."
                                                ]
                                            ]
                                        , p [] [ text "Happy building!" ]
                                        ]

                                Just event ->
                                    div []
                                        [ h1 [] [ text <| "No builds for \"" ++ event ++ "\" event found." ] ]
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
                            viewResourceError { resourceLabel = "builds for this repository", testLabel = "builds" }
