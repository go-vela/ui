{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.RepoSecrets exposing
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
        , code
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
import Http.Detailed
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
        ( Key
        , Org
        , Repo
        , Secret
        , SecretType
        , Secrets
        , Session
        , Team
        , UpdateSecretPayload
        , buildUpdateSecretPayload
        , encodeUpdateSecret
        , nullSecret
        , secretTypeToString
        , toSecretType
        )



-- UPDATE


update : PartialModel a msg -> Msg -> ( PartialModel a msg, Cmd msg )
update model msg =
    let
        secretsModel =
            model.secretsModel

        ( sm, action ) =
            case msg of
                SelectSecret selection ->
                    ( { secretsModel
                        | selectedSecret = selection
                        , manageState = selectionToManageState selection
                        , secretAdd = initSecretAdd selection secretsModel
                        , secretUpdate = initSecretUpdate selection secretsModel
                      }
                    , Cmd.none
                    )

                CancelUpdate ->
                    ( { secretsModel
                        | selectedSecret = "default"
                        , manageState = selectionToManageState "default"
                      }
                    , Cmd.none
                    )

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
                            (secretTypeToString secret.type_)
                            secretsModel.org
                            (getKey secretsModel secret)
                            body
                    )

                UpdateSecret ->
                    let
                        secret =
                            secretsModel.secretUpdate

                        name =
                            getSelectedSecretName secretsModel

                        payload : UpdateSecretPayload
                        payload =
                            toUpdateSecretPayload secret

                        body : Http.Body
                        body =
                            Http.jsonBody <| encodeUpdateSecret payload
                    in
                    ( secretsModel
                    , Api.try secretsModel.secretResponse <|
                        Api.updateSecret model
                            (secretTypeToString secret.type_)
                            secretsModel.org
                            (getKey secretsModel secret)
                            name
                            body
                    )
    in
    ( { model | secretsModel = sm }, action )


defaultSecretUpdate : SecretUpdate
defaultSecretUpdate =
    SecretUpdate "" "" "" Vela.Repo [ "push", "pull" ] "" [] True


{-| init : takes msg updates from Main.elm and initializes secrets page input arguments
-}
init : SecretResponse msg -> SecretsResponse msg -> Args msg
init secretResponse secretsResponse =
    Args "" "" NotAsked Choose "default" defaultSecretUpdate defaultSecretUpdate secretResponse secretsResponse


{-| reinitializeSecretUpdate : takes an incoming secret and reinitializes the secrets page input arguments
-}
reinitializeSecretUpdate : Args msg -> Secret -> Args msg
reinitializeSecretUpdate secretsModel secret =
    case secretsModel.manageState of
        Add ->
            { secretsModel | secretAdd = defaultSecretUpdate }

        Update ->
            { secretsModel
                | secretUpdate = secretToSecretUpdate <| Just secret
            }

        Choose ->
            secretsModel


{-| updateSecretModel : makes an update to the appropriate secret update
-}
updateSecretModel : SecretUpdate -> Args msg -> Args msg
updateSecretModel secret secretsModel =
    case secretsModel.manageState of
        Add ->
            { secretsModel | secretAdd = secret }

        Update ->
            { secretsModel | secretUpdate = secret }

        Choose ->
            secretsModel


{-| getSecretUpdate : gets the appropriate secret update based on manage state
-}
getSecretUpdate : Args msg -> Maybe SecretUpdate
getSecretUpdate secretsModel =
    case secretsModel.manageState of
        Add ->
            Just secretsModel.secretAdd

        Update ->
            Just secretsModel.secretUpdate

        Choose ->
            Nothing


{-| onChangeStringField : takes field and value and updates the secrets model
-}
onChangeStringField : String -> String -> Args msg -> Args msg
onChangeStringField field value secretsModel =
    let
        secretUpdate =
            getSecretUpdate secretsModel
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
        "type" ->
            { secret | type_ = toSecretType value }

        "team" ->
            { secret | team = value }

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
            getSecretUpdate secretsModel
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
            getSecretUpdate secretsModel
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
            getSecretUpdate secretsModel
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
            getSecretUpdate secretsModel
    in
    case secretUpdate of
        Just s ->
            updateSecretModel { s | allowCommand = Util.yesNoToBool allow } secretsModel

        Nothing ->
            secretsModel



-- VIEW


{-| view : takes model and renders page for managing repo secrets
-}
view : PartialModel a msg -> Html Msg
view model =
    let
        secretsModel =
            model.secretsModel
    in
    case secretsModel.secrets of
        Success secrets ->
            div []
                [ div [ class "manage-secrets", Util.testAttribute "manage-secrets" ]
                    [ div []
                        [ Html.h2 [] [ text "Manage Secrets" ]
                        , secretForm secretsModel secrets
                        ]
                    ]
                , Table.Table.view [] []
                ]

        _ ->
            div [] [ largeLoader ]


{-| secretForm : renders secret update form based on manage state
-}
secretForm : Args msg -> Secrets -> Html Msg
secretForm secretsModel secrets =
    div []
        [ selectSecret secretsModel secrets
        , case secretsModel.manageState of
            Add ->
                addSecret secretsModel

            Update ->
                manageSecret secretsModel

            Choose ->
                text ""
        ]


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
        , typeSelect secretUpdate
        , teamInput secretUpdate
        , eventsSelect secretUpdate
        , imagesInput secretUpdate secretUpdate.imageInput
        , help
        , div [ class "-m-t" ]
            [ Html.button [ class "button", class "-outline", onClick Pages.Secrets.Types.AddSecret ] [ text "Add" ]
            , Html.button
                [ class "-m-l"
                , class "button"
                , class "-outline"
                , onClick CancelUpdate
                ]
                [ text "Cancel" ]
            ]
        ]


{-| manageSecret : renders secret update form for updating a pre existing secret
-}
manageSecret : Args msg -> Html Msg
manageSecret secretsModel =
    let
        secretUpdate =
            secretsModel.secretUpdate
    in
    div [ class "secret-form" ]
        [ Html.h4 [ class "field-header" ] [ text "New Value" ]
        , valueInput secretUpdate.value "Secret Value (leave blank to make no change)"
        , teamInput secretUpdate
        , eventsSelect secretUpdate
        , imagesInput secretUpdate secretUpdate.imageInput
        , allowCommandCheckbox secretUpdate
        , help
        , div [ class "-m-t" ]
            [ Html.button [ class "button", class "-outline", onClick UpdateSecret ] [ text "Update" ]
            , Html.button
                [ class "-m-l"
                , class "button"
                , class "-outline"
                , onClick CancelUpdate
                ]
                [ text "Cancel" ]
            ]
        ]


{-| selectSecret : renders secret selection box
-}
selectSecret : Args msg -> Secrets -> Html Msg
selectSecret secretsModel secrets =
    div []
        [ Html.h4 [ class "field-header" ] [ text "Secret" ]
        , Html.select
            [ class "select-secret"
            , value secretsModel.selectedSecret
            , onInput SelectSecret
            ]
          <|
            secretsToOptions secrets
        ]


{-| secretsToOptions : converts secrets to Html options
-}
secretsToOptions : Secrets -> List (Html Msg)
secretsToOptions secrets =
    defaultOptions ++ List.map secretToOption secrets


{-| secretsToOption : converts secret to Html option
-}
secretToOption : Secret -> Html Msg
secretToOption secret =
    Html.option [ value <| String.fromInt secret.id ] [ text secret.name ]


{-| defaultOptions : default secrets Html options
-}
defaultOptions : List (Html Msg)
defaultOptions =
    [ Html.option [ value "default" ]
        [ text "Select Secret" ]
    , Html.option [ value "new" ] [ text "<NEW SECRET>" ]
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


{-| typeSelect : renders type input selection
-}
typeSelect : SecretUpdate -> Html Msg
typeSelect secret =
    Html.section [ class "type", Util.testAttribute "" ]
        [ Html.h4 [ class "field-header" ] [ text "Type" ]
        , div
            [ class "form-controls", class "-row" ]
            [ radio (secretTypeToString secret.type_) "repo" "Repo" <| OnChangeStringField "type" "repo"
            , radio (secretTypeToString secret.type_) "org" "Org (current org)" <| OnChangeStringField "type" "org"
            , radio (secretTypeToString secret.type_) "shared" "Shared" <| OnChangeStringField "type" "shared"
            ]
        ]


{-| teamInput : renders team input box
-}
teamInput : SecretUpdate -> Html Msg
teamInput secret =
    case secret.type_ of
        Vela.Shared ->
            div []
                [ Html.h4 [ class "field-header" ] [ text "Team" ]
                , div []
                    [ Html.textarea
                        [ value secret.team
                        , onInput <| OnChangeStringField "team"
                        , class "team-value"
                        , Html.Attributes.placeholder "Team Name"
                        ]
                        []
                    ]
                ]

        _ ->
            text ""


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
getKey : Args msg -> SecretUpdate -> String
getKey secretsModel secret =
    case secret.type_ of
        Vela.Repo ->
            secretsModel.repo

        Vela.Org ->
            "*"

        Vela.Shared ->
            secret.team


{-| toAddSecretPayload : builds payload for adding secret
-}
toAddSecretPayload : Args msg -> SecretUpdate -> UpdateSecretPayload
toAddSecretPayload secretsModel secret =
    let
        args =
            case secret.type_ of
                Vela.Repo ->
                    { repo = Just secretsModel.repo, team = Nothing }

                Vela.Org ->
                    { repo = Just "*", team = Nothing }

                Vela.Shared ->
                    { repo = Nothing, team = stringToMaybe secret.team }
    in
    buildUpdateSecretPayload
        (Just secret.type_)
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
toUpdateSecretPayload : SecretUpdate -> UpdateSecretPayload
toUpdateSecretPayload secret =
    let
        args =
            { type_ = Just secret.type_
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


{-| selectionToManageState : converts selection string to a potentially new manage state
-}
selectionToManageState : String -> ManageSecretState
selectionToManageState selection =
    case selection of
        "default" ->
            Choose

        "new" ->
            Add

        _ ->
            Update


{-| initSecretAdd : takes secret selection and returns the appropriate secret update record
-}
initSecretAdd : String -> Args msg -> SecretUpdate
initSecretAdd selection secretsModel =
    case selection of
        "default" ->
            secretsModel.secretAdd

        "new" ->
            secretsModel.secretAdd

        _ ->
            secretsModel.secretUpdate


{-| initSecretUpdate : initializes secret update based on selection and secrets model
-}
initSecretUpdate : String -> Args msg -> SecretUpdate
initSecretUpdate selection secretsModel =
    if selection == secretsModel.selectedSecret then
        secretsModel.secretUpdate

    else
        secretToSecretUpdate <| getSelectedSecret { secretsModel | selectedSecret = selection }


{-| secretToSecretUpdate : takes selected secret and converts it to SecretUpdate for use in secrets form
-}
secretToSecretUpdate : Maybe Secret -> SecretUpdate
secretToSecretUpdate selectedSecret =
    case selectedSecret of
        Just secret ->
            SecretUpdate secret.team secret.name "" secret.type_ secret.events "" secret.images secret.allowCommand

        _ ->
            defaultSecretUpdate


{-| getSelectedSecret : takes secrets model and extracts selected sercret record
-}
getSelectedSecret : Args msg -> Maybe Secret
getSelectedSecret secretsModel =
    Util.getById (Maybe.withDefault -1 <| String.toInt secretsModel.selectedSecret) <|
        case secretsModel.secrets of
            Success s ->
                s

            _ ->
                []


{-| getSelectedSecretName : extracts secret name from secrets models
-}
getSelectedSecretName : Args msg -> String
getSelectedSecretName secretsModel =
    let
        secret =
            getSelectedSecret secretsModel
    in
    secret
        |> Maybe.withDefault nullSecret
        |> .name


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
