{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.Update exposing
    ( init
    , reinitializeSecretAdd
    , reinitializeSecretUpdate
    , update
    , updateSecretModel
    )

import Alerts exposing (Alert)
import Api
import Errors exposing (addError, detailedErrorToString, toFailure)
import Http
import Http.Detailed
import List.Extra
import Msg
import Pages.Secrets.Model
    exposing
        ( Model
        , Msg(..)
        , PartialModel
        , SecretForm
        , defaultSecretUpdate
        )
import RemoteData exposing (RemoteData(..))
import Routes
import String.Extra
import Toasty as Alerting exposing (Stack)
import Util exposing (stringToMaybe)
import Vela
    exposing
        ( Secret
        , SecretType(..)
        , UpdateSecretPayload
        , buildUpdateSecretPayload
        , encodeUpdateSecret
        , secretTypeToString
        )


{-| init : takes msg updates from Main.elm and initializes secrets page input arguments
-}
init : Model
init =
    Model "native"
        ""
        ""
        ""
        Vela.RepoSecret
        NotAsked
        NotAsked
        defaultSecretUpdate
        []


{-| reinitializeSecretAdd : takes an incoming secret and reinitializes the secrets page input arguments
-}
reinitializeSecretAdd : Model -> Model
reinitializeSecretAdd secretsModel =
    { secretsModel | form = defaultSecretUpdate, secret = RemoteData.NotAsked }


{-| reinitializeSecretUpdate : takes an incoming secret and reinitializes the secrets page input arguments
-}
reinitializeSecretUpdate : Model -> Secret -> Model
reinitializeSecretUpdate secretsModel secret =
    { secretsModel | form = initSecretUpdate secret, secret = RemoteData.succeed secret }


initSecretUpdate : Secret -> SecretForm
initSecretUpdate secret =
    SecretForm secret.name "" secret.events "" secret.images secret.allowCommand


{-| updateSecretModel : makes an update to the appropriate secret update
-}
updateSecretModel : SecretForm -> Model -> Model
updateSecretModel secret secretsModel =
    { secretsModel | form = secret }


{-| onChangeStringField : takes field and value and updates the secrets model
-}
onChangeStringField : String -> String -> Model -> Model
onChangeStringField field value secretsModel =
    let
        secretUpdate =
            Just secretsModel.form
    in
    case secretUpdate of
        Just s ->
            updateSecretModel (updateSecretField field value s) secretsModel

        Nothing ->
            secretsModel


{-| updateSecretField : takes field and value and updates the secret update field
-}
updateSecretField : String -> String -> SecretForm -> SecretForm
updateSecretField field value secret =
    case field of
        "name" ->
            { secret | name = String.replace " " "" value }

        "value" ->
            { secret | value = value }

        "imageInput" ->
            { secret | imageInput = String.replace " " "" value }

        _ ->
            secret


{-| onChangeEvent : takes event and updates the secrets model based on the appropriate event
-}
onChangeEvent : String -> Model -> Model
onChangeEvent event secretsModel =
    let
        secretUpdate =
            Just secretsModel.form
    in
    case secretUpdate of
        Just s ->
            updateSecretModel (updateSecretEvents event s) secretsModel

        Nothing ->
            secretsModel


{-| updateSecretEvents : takes event and updates secret update events
-}
updateSecretEvents : String -> SecretForm -> SecretForm
updateSecretEvents event secret =
    { secret | events = toggleEvent event secret.events }


{-| onAddImage : takes image and updates secret update images
-}
onAddImage : String -> Model -> Model
onAddImage image secretsModel =
    let
        secretUpdate =
            Just secretsModel.form
    in
    case secretUpdate of
        Just s ->
            updateSecretModel (addImage image s) secretsModel

        Nothing ->
            secretsModel


{-| addImage : takes image and adds it to secret update images
-}
addImage : String -> SecretForm -> SecretForm
addImage image secret =
    { secret | imageInput = "", images = Util.filterEmptyList <| List.Extra.unique <| image :: secret.images }


{-| onRemoveImage : takes image and removes it to from secret update images
-}
onRemoveImage : String -> Model -> Model
onRemoveImage image secretsModel =
    let
        secretUpdate =
            Just secretsModel.form
    in
    case secretUpdate of
        Just s ->
            updateSecretModel (removeImage image s) secretsModel

        Nothing ->
            secretsModel


{-| removeImage : takes image and removes it to from secret update images
-}
removeImage : String -> SecretForm -> SecretForm
removeImage image secret =
    { secret | images = List.Extra.remove image secret.images }


{-| onChangeAllowCommand : updates allow\_command field on secret update
-}
onChangeAllowCommand : String -> Model -> Model
onChangeAllowCommand allow secretsModel =
    let
        secretUpdate =
            Just secretsModel.form
    in
    case secretUpdate of
        Just s ->
            updateSecretModel { s | allowCommand = Util.yesNoToBool allow } secretsModel

        Nothing ->
            secretsModel


{-| toggleEvent : takes event and toggles inclusion in the events array
-}
toggleEvent : String -> List String -> List String
toggleEvent event events =
    if List.member event events && List.length events > 1 then
        List.Extra.remove event events

    else
        event :: events


{-| getKey : gets the appropriate secret key based on type
-}
getKey : Model -> String
getKey secretsModel =
    case secretsModel.type_ of
        Vela.RepoSecret ->
            secretsModel.repo

        Vela.OrgSecret ->
            "*"

        Vela.SharedSecret ->
            secretsModel.team


{-| toAddSecretPayload : builds payload for adding secret
-}
toAddSecretPayload : Model -> SecretForm -> UpdateSecretPayload
toAddSecretPayload secretsModel secret =
    let
        args =
            case secretsModel.type_ of
                Vela.RepoSecret ->
                    { repo = Just secretsModel.repo, team = Nothing }

                Vela.OrgSecret ->
                    { repo = Just "*", team = Nothing }

                Vela.SharedSecret ->
                    { repo = Nothing, team = stringToMaybe secretsModel.team }
    in
    buildUpdateSecretPayload
        (Just secretsModel.type_)
        (Just secretsModel.org)
        args.repo
        args.team
        (stringToMaybe secret.name)
        (stringToMaybe secret.value)
        (Just secret.events)
        (Just secret.images)
        Nothing


{-| toUpdateSecretPayload : builds payload for updating secret
-}
toUpdateSecretPayload : Model -> SecretForm -> UpdateSecretPayload
toUpdateSecretPayload secretsModel secret =
    let
        args =
            { type_ = Just secretsModel.type_
            , org = Nothing
            , repo = Nothing
            , team = Nothing
            , name = Nothing
            , value = stringToMaybe secret.value
            , events = Just secret.events
            , images = Just secret.images
            , allowCommand = Just secret.allowCommand
            }
    in
    buildUpdateSecretPayload args.type_ args.org args.repo args.team args.name args.value args.events args.images args.allowCommand


{-| addSecretResponseAlert : takes secret and produces Toasty alert for when adding a secret
-}
addSecretResponseAlert :
    Secret
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
addSecretResponseAlert secret =
    let
        type_ =
            secretTypeToString secret.type_

        msg =
            secret.name ++ " added to " ++ type_ ++ " secrets."
    in
    Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" msg Nothing)


{-| updateSecretResponseAlert : takes secret and produces Toasty alert for when updating a secret
-}
updateSecretResponseAlert :
    Secret
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
updateSecretResponseAlert secret =
    let
        type_ =
            secretTypeToString secret.type_

        msg =
            String.Extra.toSentenceCase <| type_ ++ " secret " ++ secret.name ++ " updated."
    in
    Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" msg Nothing)



-- UPDATE


update : PartialModel a -> Msg -> ( PartialModel a, Cmd Msg )
update model msg =
    let
        secretsModel =
            model.secretsModel

        ( newModel, action ) =
            case msg of
                OnChangeStringField field value ->
                    ( { model | secretsModel = onChangeStringField field value secretsModel }, Cmd.none )

                OnChangeEvent event _ ->
                    ( { model | secretsModel = onChangeEvent event secretsModel }, Cmd.none )

                AddImage image ->
                    ( { model | secretsModel = onAddImage image secretsModel }, Cmd.none )

                RemoveImage image ->
                    ( { model | secretsModel = onRemoveImage image secretsModel }, Cmd.none )

                OnChangeAllowCommand allow ->
                    ( { model | secretsModel = onChangeAllowCommand allow secretsModel }, Cmd.none )

                AddSecret engine ->
                    let
                        secret =
                            secretsModel.form

                        payload : UpdateSecretPayload
                        payload =
                            toAddSecretPayload secretsModel secret

                        body : Http.Body
                        body =
                            Http.jsonBody <| encodeUpdateSecret payload
                    in
                    ( model
                    , Api.try AddSecretResponse <|
                        Api.addSecret model
                            engine
                            (secretTypeToString secretsModel.type_)
                            secretsModel.org
                            (getKey secretsModel)
                            body
                    )

                UpdateSecret engine ->
                    let
                        secret =
                            secretsModel.form

                        payload : UpdateSecretPayload
                        payload =
                            toUpdateSecretPayload secretsModel secret

                        body : Http.Body
                        body =
                            Http.jsonBody <| encodeUpdateSecret payload
                    in
                    ( model
                    , Api.try UpdateSecretResponse <|
                        Api.updateSecret model
                            engine
                            (secretTypeToString secretsModel.type_)
                            secretsModel.org
                            (getKey secretsModel)
                            secret.name
                            body
                    )

                AddSecretResponse response ->
                    case response of
                        Ok ( _, secret ) ->
                            let
                                updatedSecretsModel =
                                    reinitializeSecretAdd secretsModel
                            in
                            ( { model | secretsModel = updatedSecretsModel }
                            , Cmd.none
                            )
                                |> addSecretResponseAlert secret

                        Err error ->
                            ( model, addError error HandleError )

                UpdateSecretResponse response ->
                    case response of
                        Ok ( _, secret ) ->
                            let
                                updatedSecretsModel =
                                    reinitializeSecretUpdate secretsModel secret
                            in
                            ( { model | secretsModel = updatedSecretsModel }
                            , Cmd.none
                            )
                                |> updateSecretResponseAlert secret

                        Err error ->
                            ( model, addError error HandleError )

                HandleError error ->
                    ( model, Cmd.none )
                        |> Alerting.addToastIfUnique Alerts.errorConfig AlertsUpdate (Alerts.Error "Error" error)

                AlertsUpdate subMsg ->
                    Alerting.update Alerts.successConfig AlertsUpdate subMsg model
    in
    ( newModel, action )
