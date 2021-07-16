{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.Update exposing
    ( init
    , reinitializeDeployment
    , initializeFormFromDeployment
    , update
    )

import Api
import Http
import List.Extra
import Pages.Deployments.Model exposing (DeploymentForm, DeploymentResponse, Model, Msg(..), PartialModel, defaultDeploymentForm)
import RemoteData exposing (RemoteData(..))
import Util exposing (stringToMaybe)
import Vela exposing (DeploymentPayload, KeyValuePair, buildDeploymentPayload, encodeDeploymentPayload)



-- INIT


{-| init : takes msg updates from Main.elm and initializes deployment page input arguments
-}
init : DeploymentResponse msg -> Model msg
init deploymentResponse =
    Model ""
        ""
        ""
        defaultDeploymentForm
        NotAsked
        deploymentResponse


{-| reinitializeDeployment : takes an incoming deployment and reinitialized page input arguments
-}
reinitializeDeployment : Model msg -> Model msg
reinitializeDeployment deploymentModel =
    { deploymentModel | form = defaultDeploymentForm }

initializeFormFromDeployment : String -> String -> String -> String -> DeploymentForm
initializeFormFromDeployment description ref target task =
    DeploymentForm ""
        description
        []
        ref
        target
        task
        ""
        ""

{-| updateDeploymentField : takes field and value and updates the deployment field
-}
updateDeploymentField : String -> String -> DeploymentForm -> DeploymentForm
updateDeploymentField field value form =
    case field of
        "Target" ->
            { form | target = String.replace " " "" value }

        "Task" ->
            { form | task = String.replace " " "" value }

        "Ref" ->
            { form | ref = String.replace " " "" value }

        "Description" ->
            { form | description = value }

        "parameterInputKey" ->
            { form | parameterInputKey = String.replace " " "" value }

        "parameterInputValue" ->
            { form | parameterInputValue = value }

        _ ->
            form


{-| updateDeploymentModel : makes an update to the appropriate deployment update
-}
updateDeploymentModel : DeploymentForm -> Model msg -> Model msg
updateDeploymentModel value form =
    { form | form = value }


{-| onChangeStringField : takes field and value and updates the deployment model
-}
onChangeStringField : String -> String -> Model msg -> Model msg
onChangeStringField field value deploymentModel =
    let
        deploymentUpdate =
            Just deploymentModel.form
    in
    case deploymentUpdate of
        Just s ->
            updateDeploymentModel (updateDeploymentField field value s) deploymentModel

        Nothing ->
            deploymentModel


{-| onAddParameter : takes parameter and updates the list of parameters
-}
onAddParameter : DeploymentForm -> Model msg -> Model msg
onAddParameter deploymentUpdate deploymentModel =
    case deploymentUpdate of
        s ->
            updateDeploymentModel (addParameter s) deploymentModel


{-| toKeyValue : creates a keyValuePair from form input
-}
toKeyValue : String -> String -> KeyValuePair
toKeyValue key value =
    { key = key, value = value }


{-| addParameter : takes parameter from the form and adds it to deployment parameter list
-}
addParameter : DeploymentForm -> DeploymentForm
addParameter form =
    { form
        | parameterInputValue = ""
        , parameterInputKey = ""
        , payload = toKeyValue form.parameterInputKey form.parameterInputValue :: form.payload
    }


{-| onRemoveParameter : takes parameter and removes it to from deployment parameters
-}
onRemoveParameter : KeyValuePair -> Model msg -> Model msg
onRemoveParameter parameter deploymentModel =
    let
        deploymentUpdate =
            Just deploymentModel.form
    in
    case deploymentUpdate of
        Just s ->
            updateDeploymentModel (removeParameter parameter s) deploymentModel

        Nothing ->
            deploymentModel


{-| removeParameter : takes parameter and removes it to from deployment parameters
-}
removeParameter : KeyValuePair -> DeploymentForm -> DeploymentForm
removeParameter param parameter =
    { parameter | payload = List.Extra.remove param parameter.payload }



-- UPDATE


{-| toDeploymentPayload : builds payload for adding a deployment
-}
toDeploymentPayload : Model msg -> DeploymentForm -> DeploymentPayload
toDeploymentPayload deploymentModel deployment =
    buildDeploymentPayload
        (Just deploymentModel.org)
        (Just deploymentModel.repo)
        (stringToMaybe deployment.commit)
        (stringToMaybe deployment.description)
        (stringToMaybe deployment.ref)
        (stringToMaybe deployment.target)
        (stringToMaybe deployment.task)
        (Just deployment.payload)


applyDefaults : DeploymentForm -> DeploymentForm
applyDefaults form =
    DeploymentForm
        form.commit
        (if form.description == "" then
            "Deployment request from Vela"

         else
            form.description
        )
        form.payload
        (if form.ref == "" then
            "refs/heads/master"

         else
            form.ref
        )
        (if form.target == "" then
            "production"

         else
            form.target
        )
        (if form.task == "" then
            "deploy:vela"

         else
            form.task
        )
        ""
        ""


update : PartialModel a msg -> Msg -> ( PartialModel a msg, Cmd msg )
update model msg =
    let
        deploymentModel =
            model.deploymentModel

        ( sm, action ) =
            case msg of
                OnChangeStringField field value ->
                    ( onChangeStringField field value deploymentModel, Cmd.none )

                AddParameter deploymentForm ->
                    ( onAddParameter deploymentForm deploymentModel, Cmd.none )

                RemoveParameter keyValuePair ->
                    ( onRemoveParameter keyValuePair deploymentModel, Cmd.none )

                PromoteDeployment b ->
                    let
                        df = initializeFormFromDeployment b.message b.ref b.deploy ""
                        dm = model.deploymentModel
                        promotedDeploymentModel = {dm | form = df}
                    in
                        (promotedDeploymentModel, Cmd.none)

                AddDeployment ->
                    let
                        deployment =
                            deploymentModel.form

                        payload : DeploymentPayload
                        payload =
                            toDeploymentPayload deploymentModel (applyDefaults deployment)

                        body : Http.Body
                        body =
                            Http.jsonBody <| encodeDeploymentPayload payload
                    in
                    ( deploymentModel
                    , Api.try deploymentModel.deploymentResponse <|
                        Api.addDeployment model
                            deploymentModel.org
                            deploymentModel.repo
                            body
                    )
    in
    ( { model | deploymentModel = sm }, action )
