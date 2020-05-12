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

import Api
import Http
import List.Extra
import Pages.Secrets.Model
    exposing
        ( AddSecretResponse
        , Model
        , Msg(..)
        , PartialModel
        , SecretForm
        , SecretResponse
        , SecretsResponse
        , UpdateSecretResponse
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
init : SecretResponse msg -> SecretsResponse msg -> AddSecretResponse msg -> UpdateSecretResponse msg -> Model msg
init secretResponse secretsResponse addSecretResponse updateSecretResponse =
    Model "native"
        ""
        ""
        ""
        Vela.RepoSecret
        NotAsked
        NotAsked
        defaultSecretUpdate
        secretResponse
        secretsResponse
        addSecretResponse
        updateSecretResponse
        []


{-| reinitializeSecretAdd : takes an incoming secret and reinitializes the secrets page input arguments
-}
reinitializeSecretAdd : Model msg -> Model msg
reinitializeSecretAdd secretsModel =
    { secretsModel | form = defaultSecretUpdate, secret = RemoteData.NotAsked }


{-| reinitializeSecretUpdate : takes an incoming secret and reinitializes the secrets page input arguments
-}
reinitializeSecretUpdate : Model msg -> Secret -> Model msg
reinitializeSecretUpdate secretsModel secret =
    { secretsModel | form = initSecretUpdate secret, secret = RemoteData.succeed secret }


initSecretUpdate : Secret -> SecretForm
initSecretUpdate secret =
    SecretForm secret.name "" secret.events "" secret.images secret.allowCommand


{-| updateSecretModel : makes an update to the appropriate secret update
-}
updateSecretModel : SecretForm -> Model msg -> Model msg
updateSecretModel secret secretsModel =
    { secretsModel | form = secret }


{-| onChangeStringField : takes field and value and updates the secrets model
-}
onChangeStringField : String -> String -> Model msg -> Model msg
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
onChangeEvent : String -> Model msg -> Model msg
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
onAddImage : String -> Model msg -> Model msg
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
onRemoveImage : String -> Model msg -> Model msg
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
onChangeAllowCommand : String -> Model msg -> Model msg
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
getKey : Model msg -> String
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
toAddSecretPayload : Model msg -> SecretForm -> UpdateSecretPayload
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
toUpdateSecretPayload : Model msg -> SecretForm -> UpdateSecretPayload
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

                Pages.Secrets.Model.AddSecret engine ->
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
                    ( secretsModel
                    , Api.try secretsModel.addSecretResponse <|
                        Api.addSecret model
                            engine
                            (secretTypeToString secretsModel.type_)
                            secretsModel.org
                            (getKey secretsModel)
                            body
                    )

                Pages.Secrets.Model.UpdateSecret engine ->
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
                    ( secretsModel
                    , Api.try secretsModel.updateSecretResponse <|
                        Api.updateSecret model
                            engine
                            (secretTypeToString secretsModel.type_)
                            secretsModel.org
                            (getKey secretsModel)
                            secret.name
                            body
                    )
    in
    ( { model | secretsModel = sm }, action )
