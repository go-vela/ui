{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.Update exposing
    ( init
    , update
    )

import List.Extra
import Pages.Deployments.Model exposing (DeploymentForm, DeploymentResponse, Model, Msg(..), PartialModel, defaultDeploymentForm)
import Util
import Vela exposing (KeyValuePair)


-- INIT

{-| init : takes msg updates from Main.elm and initializes secrets page input arguments
-}
init : DeploymentResponse msg -> Model msg
init deploymentResponse =
    Model "native"
        ""
        ""
        ""
        defaultDeploymentForm
        Nothing

{-| updateSecretField : takes field and value and updates the secret update field
-}
updateDeploymentField : String -> String -> DeploymentForm -> DeploymentForm
updateDeploymentField field value form =
    case field of
        "target" ->
            { form | target = String.replace " " "" value }

        "Ref" ->
            { form | ref = String.replace " " "" value }

        "Description" ->
            { form | description = String.replace " " "" value }

        "parameterInputKey" ->
            { form | parameterInputKey = String.replace " " "" value }

        "parameterInputValue" ->
            { form | parameterInputValue = value }

        _ ->
            form

{-| updateDeploymentModel : makes an update to the appropriate secret update
-}
updateDeploymentModel : DeploymentForm -> Model msg -> Model msg
updateDeploymentModel value form =
    { form | form = value }



{-| onChangeStringField : takes field and value and updates the secrets model
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

{-| onAddImage : takes image and updates secret update images
-}
onAddParamter : DeploymentForm -> Model msg -> Model msg
onAddParamter deploymentUpdate deploymentModel =
    case deploymentUpdate of
        s ->
            updateDeploymentModel (addParameter s) deploymentModel

toKeyValue : String -> String -> KeyValuePair
toKeyValue key value =
    {key=key, value=value}

{-| addImage : takes image and adds it to secret update images
-}
addParameter : DeploymentForm -> DeploymentForm
addParameter form =
    { form |
    parameterInputValue = "",
    parameterInputKey = "",
    payload = (toKeyValue form.parameterInputKey form.parameterInputValue) :: form.payload }


{-| onRemoveImage : takes image and removes it to from secret update images
-}
onRemoveParameter : KeyValuePair -> Model msg -> Model msg
onRemoveParameter parameter deploymentModel =
    let
        secretUpdate =
            Just deploymentModel.form
    in
    case secretUpdate of
        Just s ->
            updateDeploymentModel (removeParameter parameter s) deploymentModel

        Nothing ->
            deploymentModel


{-| removeImage : takes image and removes it to from secret update images
-}
removeParameter : KeyValuePair -> DeploymentForm -> DeploymentForm
removeParameter image parameter =
    { parameter | payload = List.Extra.remove image parameter.payload }


-- UPDATE


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
                  ( onAddParamter deploymentForm deploymentModel, Cmd.none )

                RemoveParameter keyValuePair ->
                  ( onRemoveParameter keyValuePair deploymentModel, Cmd.none )

                AddDeployment engine ->
                  Debug.todo "Not Implemented"


    in
    ( { model | deploymentModel = sm }, action )
