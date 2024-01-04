{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Secrets.Update exposing
    ( deleteSecretRedirect
    , init
    , reinitializeSecretAdd
    , reinitializeSecretUpdate
    , update
    )

import Api.Api
import Api.Operations
import Http
import List.Extra
import Pages.Secrets.Model
    exposing
        ( AddSecretResponse
        , DeleteSecretResponse
        , DeleteSecretState(..)
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
import Routes
import Util exposing (stringToMaybe)
import Vela
    exposing
        ( Copy
        , Secret
        , SecretType(..)
        , UpdateSecretPayload
        , buildUpdateSecretPayload
        , encodeUpdateSecret
        , secretTypeToString
        )



-- INIT


{-| init : takes msg updates from Main.elm and initializes secrets page input arguments
-}
init : Copy msg -> SecretResponse msg -> SecretsResponse msg -> SecretsResponse msg -> SecretsResponse msg -> AddSecretResponse msg -> UpdateSecretResponse msg -> DeleteSecretResponse msg -> Model msg
init copy secretResponse repoSecretsResponse orgSecretsResponse sharedSecretsResponse addSecretResponse updateSecretResponse deleteSecretResponse =
    Model "native"
        ""
        ""
        ""
        Vela.RepoSecret
        NotAsked
        []
        NotAsked
        []
        NotAsked
        []
        NotAsked
        defaultSecretUpdate
        copy
        secretResponse
        repoSecretsResponse
        orgSecretsResponse
        sharedSecretsResponse
        addSecretResponse
        deleteSecretResponse
        updateSecretResponse
        []
        NotAsked_



-- HELPERS


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
    SecretForm secret.name "" secret.events "" secret.images secret.allowCommand secret.team


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

        "Team" ->
            { secret | team = String.replace " " "" value }

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
                    if secretsModel.team == "*" then
                        { repo = Nothing, team = stringToMaybe secret.team }

                    else
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
        (Just secret.allowCommand)


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

                        team : String
                        team =
                            if secretsModel.team == "*" && secretsModel.type_ == SharedSecret then
                                secret.team

                            else
                                getKey secretsModel

                        body : Http.Body
                        body =
                            Http.jsonBody <| encodeUpdateSecret payload
                    in
                    ( secretsModel
                    , Api.Api.try secretsModel.addSecretResponse <|
                        Api.Operations.addSecret model
                            engine
                            (secretTypeToString secretsModel.type_)
                            secretsModel.org
                            team
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
                    , Api.Api.try secretsModel.updateSecretResponse <|
                        Api.Operations.updateSecret model
                            engine
                            (secretTypeToString secretsModel.type_)
                            secretsModel.org
                            (getKey secretsModel)
                            secret.name
                            body
                    )

                Pages.Secrets.Model.DeleteSecret engine ->
                    let
                        secret =
                            secretsModel.form

                        updatedModel =
                            case secretsModel.deleteState of
                                NotAsked_ ->
                                    { secretsModel
                                        | deleteState = Confirm
                                    }

                                Confirm ->
                                    { secretsModel
                                        | deleteState = Deleting
                                    }

                                Deleting ->
                                    secretsModel

                        doAction =
                            case secretsModel.deleteState of
                                NotAsked_ ->
                                    Cmd.none

                                Confirm ->
                                    Api.Api.tryString secretsModel.deleteSecretResponse <|
                                        Api.Operations.deleteSecret model
                                            engine
                                            (secretTypeToString secretsModel.type_)
                                            secretsModel.org
                                            (getKey secretsModel)
                                            secret.name

                                Deleting ->
                                    Cmd.none
                    in
                    ( updatedModel, doAction )

                Pages.Secrets.Model.CancelDeleteSecret ->
                    ( { secretsModel
                        | deleteState = NotAsked_
                      }
                    , Cmd.none
                    )

                Pages.Secrets.Model.Copy str ->
                    ( secretsModel, Util.dispatch <| secretsModel.copy str )
    in
    ( { model | secretsModel = sm }, action )



-- takes secretsModel and returns the URL to redirect to


deleteSecretRedirect : Model msg -> String
deleteSecretRedirect { engine, org, repo, team, type_ } =
    Routes.routeToUrl <|
        case type_ of
            Vela.OrgSecret ->
                Routes.OrgSecrets engine org Nothing Nothing

            Vela.RepoSecret ->
                Routes.RepoSecrets engine org repo Nothing Nothing

            Vela.SharedSecret ->
                Routes.SharedSecrets engine org team Nothing Nothing
