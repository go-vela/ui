{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.AddSecret exposing
    ( defaultSecretUpdate
    , init
    , reinitializeSecretUpdate
    , update
    , updateSecretModel
    , view
    )

import Api
import Html
    exposing
        ( Html
        , a
        , div
        , em
        , h4
        , section
        , span
        , text
        )
import Html.Attributes
    exposing
        ( class
        , disabled
        , href
        , placeholder
        , value
        )
import Html.Events exposing (onClick, onInput)
import Http
import List.Extra
import Pages exposing (Page(..))
import Pages.RepoSettings exposing (checkbox, radio)
import Pages.Secrets.Types
    exposing
        ( Args
        , ManageSecretState(..)
        , Msg(..)
        , PartialModel
        , SecretResponse
        , SecretUpdate
        , SecretsResponse
        )
import RemoteData exposing (RemoteData(..), WebData)
import Table.Table
import Util exposing (largeLoader)
import Vela
    exposing
        ( Repo
        , Secret
        , SecretType(..)
        , UpdateSecretPayload
        , buildUpdateSecretPayload
        , encodeUpdateSecret
        , secretTypeToString
        , toSecretType
        )


view : PartialModel a msg -> Html Msg
view model =
    div [ class "manage-secrets", Util.testAttribute "manage-secrets" ]
        [ div []
            [ Html.h2 [] [ header model.secretsModel.type_ ]
            , addSecret model.secretsModel
            ]
        ]


header : SecretType -> Html Msg
header type_ =
    case type_ of
        Vela.OrgSecret ->
            text "Add Org Secret"

        Vela.RepoSecret ->
            text "Add Repo Secret"

        Vela.SharedSecret ->
            text "Add Shared Secret"


{-| addSecret : renders secret update form for adding a new secret
-}
addSecret : Args msg -> Html Msg
addSecret secretsModel =
    let
        secretUpdate =
            secretsModel.secretAdd
    in
    div [ class "secret-form" ]
        [ Html.h4 [ class "field-header" ] [ text "Name" ]
        , nameInput secretUpdate.name False
        , Html.h4 [ class "field-header" ] [ text "Value" ]
        , valueInput secretUpdate.value "Secret Value"
        , eventsSelect secretUpdate
        , imagesInput secretUpdate secretUpdate.imageInput
        , help
        , div [ class "-m-t" ]
            [ Html.button [ class "button", class "-outline", onClick Pages.Secrets.Types.AddSecret ] [ text "Add" ]
            ]
        ]


{-| nameInput : renders name input box
-}
nameInput : String -> Bool -> Html Msg
nameInput val disable =
    div []
        [ Html.input
            [ disabled disable
            , value val
            , onInput <|
                OnChangeStringField "name"
            , class "secret-name"
            , Html.Attributes.placeholder "Secret Name"
            ]
            []
        ]


{-| valueInput : renders value input box
-}
valueInput : String -> String -> Html Msg
valueInput val placeholder_ =
    div []
        [ Html.textarea
            [ value val
            , onInput <| OnChangeStringField "value"
            , class "secret-value"
            , Html.Attributes.placeholder placeholder_
            ]
            []
        ]


{-| eventsSelect : renders events input selection
-}
eventsSelect : SecretUpdate -> Html Msg
eventsSelect secretUpdate =
    Html.section [ class "events", Util.testAttribute "" ]
        [ h4 [ class "field-header" ]
            [ text "Limit to Events"
            , span [ class "field-description" ]
                [ text "( "
                , em [] [ text "at least one event must be selected" ]
                , text " )"
                ]
            ]
        , div [ class "form-controls", class "-row" ]
            [ checkbox "Push"
                "push"
                (eventEnabled "push" secretUpdate.events)
              <|
                OnChangeEvent "push"
            , checkbox "Pull Request"
                "pull"
                (eventEnabled "pull" secretUpdate.events)
              <|
                OnChangeEvent "pull"
            , checkbox "Deploy"
                "deploy"
                (eventEnabled "deploy" secretUpdate.events)
              <|
                OnChangeEvent "deploy"
            , checkbox "Tag"
                "tag"
                (eventEnabled "tag" secretUpdate.events)
              <|
                OnChangeEvent "tag"
            ]
        ]


{-| imagesInput : renders images input box and images
-}
imagesInput : SecretUpdate -> String -> Html Msg
imagesInput secret imageInput =
    Html.section [ class "image", Util.testAttribute "" ]
        [ Html.h4 [ class "field-header" ]
            [ text "Limit to Docker Images"
            , span
                [ class "field-description" ]
                [ em [] [ text "(Leave blank to enable this secret for all images)" ]
                ]
            ]
        , div []
            [ Html.input
                [ placeholder "Image Name"
                , onInput <| OnChangeStringField "imageInput"
                , value imageInput
                ]
                []
            , Html.button
                [ class "button"
                , class "-outline"
                , class "-slim"
                , class "-m-l"
                , onClick <| AddImage <| String.toLower imageInput
                , disabled <| String.isEmpty <| String.trim imageInput
                ]
                [ text "Add Image"
                ]
            ]
        , div [ class "images" ] <| viewAddedImages secret.images
        ]


{-| viewAddedImages : renders added images
-}
viewAddedImages : List String -> List (Html Msg)
viewAddedImages images =
    if List.length images > 0 then
        List.map addedImage <| List.reverse images

    else
        noImages


{-| noImages : renders when no images have been added
-}
noImages : List (Html Msg)
noImages =
    [ div [ class "added-image" ]
        [ div [ class "name" ] [ text "enabled for all images" ]

        -- add button to match style
        , Html.button
            [ class "button"
            , class "-outline"
            , class "-hide"
            , disabled True
            ]
            [ text "remove"
            ]
        ]
    ]


{-| addedImage : renders added image
-}
addedImage : String -> Html Msg
addedImage image =
    div [ class "added-image", class "chevron" ]
        [ div [ class "name" ] [ text image ]
        , Html.button
            [ class "button"
            , class "-outline"
            , onClick <| RemoveImage image
            ]
            [ text "remove"
            ]
        ]


{-| allowCommandCheckbox : renders checkbox inputs for selecting allow\_command
-}
allowCommandCheckbox : SecretUpdate -> Html Msg
allowCommandCheckbox secretUpdate =
    section [ class "type", Util.testAttribute "" ]
        [ h4 [ class "field-header" ]
            [ text "Allow Commands"
            , span [ class "field-description" ]
                [ text "( "
                , em [] [ text "\"No\" will disable this secret in " ]
                , span [ class "-code" ] [ text "commands" ]
                , text " )"
                ]
            ]
        , div
            [ class "form-controls", class "-row" ]
            [ radio (Util.boolToYesNo secretUpdate.allowCommand) "yes" "Yes" <| OnChangeAllowCommand "yes"
            , radio (Util.boolToYesNo secretUpdate.allowCommand) "no" "No" <| OnChangeAllowCommand "no"
            ]
        ]


{-| help : renders help msg pointing to Vela docs
-}
help : Html Msg
help =
    div [] [ text "Need help? Visit our ", a [ href secretsDocsURL ] [ text "docs" ], text "!" ]


secretsDocsURL : String
secretsDocsURL =
    "https://go-vela.github.io/docs/concepts/pipeline/secrets/"



-- HELPERS


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


{-| toUpdateSecretPayload : builds payload for updating secret
-}
toUpdateSecretPayload : Args msg -> SecretUpdate -> UpdateSecretPayload
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


{-| stringToMaybe : takes string and returns nothing if trimmed string is empty
-}
stringToMaybe : String -> Maybe String
stringToMaybe str =
    let
        trimmed =
            String.trim str
    in
    if String.isEmpty trimmed then
        Nothing

    else
        Just trimmed


{-| eventEnabled : takes event and returns if it is enabled
-}
eventEnabled : String -> List String -> Bool
eventEnabled event =
    List.member event


{-| toggleEvent : takes event and toggles inclusion in the events array
-}
toggleEvent : String -> List String -> List String
toggleEvent event events =
    if List.member event events && List.length events > 1 then
        List.Extra.remove event events

    else
        event :: events



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


defaultSecretUpdate : SecretUpdate
defaultSecretUpdate =
    SecretUpdate "" "" [ "push", "pull" ] "" [] True


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
