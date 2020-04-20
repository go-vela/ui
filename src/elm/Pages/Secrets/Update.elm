{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.Update exposing
    ( init
    , reinitializeSecretUpdate
    , update
    , updateSecretModel
    )

import Api
import Http
import List.Extra
import Pages.Secrets.Types
    exposing
        ( Args
        , Msg(..)
        , PartialModel
        , SecretResponse
        , SecretUpdate
        , SecretsResponse
        , defaultSecretUpdate
        )
import RemoteData exposing (RemoteData(..))
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
init : SecretResponse msg -> SecretsResponse msg -> Args msg
init secretResponse secretsResponse =
    Args "" "" "" Vela.RepoSecret NotAsked defaultSecretUpdate defaultSecretUpdate secretResponse secretsResponse


{-| reinitializeSecretUpdate : takes an incoming secret and reinitializes the secrets page input arguments
-}
reinitializeSecretUpdate : Args msg -> Secret -> Args msg
reinitializeSecretUpdate secretsModel secret =
    { secretsModel | secretAdd = defaultSecretUpdate }


{-| updateSecretModel : makes an update to the appropriate secret update
-}
updateSecretModel : SecretUpdate -> Args msg -> Args msg
updateSecretModel secret secretsModel =
    { secretsModel | secretAdd = secret }


{-| onChangeStringField : takes field and value and updates the secrets model
-}
onChangeStringField : String -> String -> Args msg -> Args msg
onChangeStringField field value secretsModel =
    let
        secretUpdate =
            Just secretsModel.secretAdd
    in
    case secretUpdate of
        Just s ->
            updateSecretModel (updateSecretField field value s) secretsModel

        Nothing ->
            secretsModel


{-| updateSecretField : takes field and value and updates the secret update field
-}
updateSecretField : String -> String -> SecretUpdate -> SecretUpdate
updateSecretField field value secret =
    case field of
        "name" ->
            { secret | name = value }

        "value" ->
            { secret | value = value }

        "imageInput" ->
            { secret | imageInput = String.replace " " "" value }

        _ ->
            secret


{-| onChangeEvent : takes event and updates the secrets model based on the appropriate event
-}
onChangeEvent : String -> Args msg -> Args msg
onChangeEvent event secretsModel =
    let
        secretUpdate =
            Just secretsModel.secretAdd
    in
    case secretUpdate of
        Just s ->
            updateSecretModel (updateSecretEvents event s) secretsModel

        Nothing ->
            secretsModel


{-| updateSecretEvents : takes event and updates secret update events
-}
updateSecretEvents : String -> SecretUpdate -> SecretUpdate
updateSecretEvents event secret =
    { secret | events = toggleEvent event secret.events }


{-| onAddImage : takes image and updates secret update images
-}
onAddImage : String -> Args msg -> Args msg
onAddImage image secretsModel =
    let
        secretUpdate =
            Just secretsModel.secretAdd
    in
    case secretUpdate of
        Just s ->
            updateSecretModel (addImage image s) secretsModel

        Nothing ->
            secretsModel


{-| addImage : takes image and adds it to secret update images
-}
addImage : String -> SecretUpdate -> SecretUpdate
addImage image secret =
    { secret | imageInput = "", images = Util.filterEmptyList <| List.Extra.unique <| image :: secret.images }


{-| onRemoveImage : takes image and removes it to from secret update images
-}
onRemoveImage : String -> Args msg -> Args msg
onRemoveImage image secretsModel =
    let
        secretUpdate =
            Just secretsModel.secretAdd
    in
    case secretUpdate of
        Just s ->
            updateSecretModel (removeImage image s) secretsModel

        Nothing ->
            secretsModel


{-| removeImage : takes image and removes it to from secret update images
-}
removeImage : String -> SecretUpdate -> SecretUpdate
removeImage image secret =
    { secret | images = List.Extra.remove image secret.images }


{-| onChangeAllowCommand : updates allow\_command field on secret update
-}
onChangeAllowCommand : String -> Args msg -> Args msg
onChangeAllowCommand allow secretsModel =
    let
        secretUpdate =
            Just secretsModel.secretAdd
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
getKey : Args msg -> String
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
toAddSecretPayload : Args msg -> SecretUpdate -> UpdateSecretPayload
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



-- UPDATE


update : PartialModel a msg -> Msg -> ( PartialModel a msg, Cmd msg )
update model msg =
    let
        secretsModel =
            model.secretsModel

        ( sm, action ) =
            case msg of
                OnChangeStringField field value ->
                    ( onChangeStringField field value secretsModel, Cmd.none )

                OnChangeEvent event _ ->
                    ( onChangeEvent event secretsModel, Cmd.none )

                AddImage image ->
                    ( onAddImage image secretsModel, Cmd.none )

                RemoveImage image ->
                    ( onRemoveImage image secretsModel, Cmd.none )

                OnChangeAllowCommand allow ->
                    ( onChangeAllowCommand allow secretsModel, Cmd.none )

                Pages.Secrets.Types.AddSecret ->
                    let
                        secret =
                            secretsModel.secretAdd

                        payload : UpdateSecretPayload
                        payload =
                            toAddSecretPayload secretsModel secret

                        body : Http.Body
                        body =
                            Http.jsonBody <| encodeUpdateSecret payload
                    in
                    ( secretsModel
                    , Api.try secretsModel.secretResponse <|
                        Api.addSecret model
                            (secretTypeToString secretsModel.type_)
                            secretsModel.org
                            (getKey secretsModel)
                            body
                    )
    in
    ( { model | secretsModel = sm }, action )
