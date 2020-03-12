{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets exposing
    ( Args
    , Msg
    , defaultSecretUpdate
    , handleSelection
    , init
    , update
    , view
    )

import Api
import Html
    exposing
        ( Html
        , a
        , br
        , code
        , div
        , em
        , h4
        , p
        , section
        , span
        , text
        )
import Html.Attributes exposing (class, disabled, placeholder, value)
import Html.Events exposing (onClick, onInput)
import Http
import Http.Detailed
import List.Extra
import Pages exposing (Page(..))
import Pages.RepoSettings exposing (checkbox, radio)
import RemoteData exposing (RemoteData(..), WebData)
import Util exposing (largeLoader)
import Vela
    exposing
        ( AddSecretPayload
        , Key
        , Name
        , Org
        , Repo
        , Secret
        , SecretType
        , Secrets
        , Session
        , Team
        , Type
        , UpdateSecretPayload
        , buildAddSecretPayload
        , buildUpdateSecretPayload
        , encodeAddSecret
        , encodeUpdateSecret
        , secretTypeToString
        , toSecretType
        )


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a msg =
    { a
        | velaAPI : String
        , session : Maybe Session
        , secretsModel : Args msg
    }


type alias Args msg =
    { org : Org
    , repo : Repo
    , secrets : WebData Secrets
    , manageState : ManageSecretState
    , selectedSecret : String
    , secretUpdate : SecretUpdate
    , secretAdd : SecretUpdate
    , secretResponse : SecretResponse msg
    , secretsResponse : SecretsResponse msg
    }


type alias SecretResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secret ) -> msg


type alias SecretsResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ) -> msg


type Msg
    = OnChangeStringField String String
    | SelectSecret String
    | OnChangeEvent String Bool
    | AddImage String
    | RemoveImage String
    | OnChangeAllowCommand String
    | CancelUpdate
    | AddSecret
    | UpdateSecret
    | NoOp


type ManageSecretState
    = Choose
    | Add
    | Update


type alias SecretUpdate =
    { team : Team
    , name : String
    , value : String
    , type_ : SecretType
    , events : List String
    , imageInput : String
    , images : List String
    , allowCommand : Bool
    }


defaultSecretUpdate : SecretUpdate
defaultSecretUpdate =
    SecretUpdate "" "" "" Vela.Repo [ "push", "pull" ] "" [] True


init : SecretResponse msg -> SecretsResponse msg -> Args msg
init secretResponse secretsResponse =
    Args "" "" NotAsked Choose "default" defaultSecretUpdate defaultSecretUpdate secretResponse secretsResponse


updateSecretModel : SecretUpdate -> Args msg -> Args msg
updateSecretModel secret secretsModel =
    case secretsModel.manageState of
        Add ->
            { secretsModel | secretAdd = secret }

        Update ->
            { secretsModel | secretUpdate = secret }

        Choose ->
            secretsModel


getSecretUpdate : Args msg -> Maybe SecretUpdate
getSecretUpdate secretsModel =
    case secretsModel.manageState of
        Add ->
            Just secretsModel.secretAdd

        Update ->
            Just secretsModel.secretUpdate

        Choose ->
            Nothing


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


updateSecretField : String -> String -> SecretUpdate -> SecretUpdate
updateSecretField field value secret =
    case field of
        "team" ->
            { secret | team = value }

        "name" ->
            { secret | name = value }

        "value" ->
            { secret | value = value }

        "imageInput" ->
            { secret | imageInput = value }

        _ ->
            secret


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


updateSecretEvents : String -> SecretUpdate -> SecretUpdate
updateSecretEvents event secret =
    { secret | events = toggleEvent event secret.events }


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


addImage : String -> SecretUpdate -> SecretUpdate
addImage image secret =
    { secret | images = Util.filterEmptyList <| List.Extra.unique <| image :: secret.images }


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


removeImage : String -> SecretUpdate -> SecretUpdate
removeImage image secret =
    { secret | images = List.Extra.remove image secret.images }


onChangeAllowCommand : String -> Args msg -> Args msg
onChangeAllowCommand allow secretsModel =
    let
        secretUpdate =
            getSecretUpdate secretsModel
    in
    case secretUpdate of
        Just s ->
            updateSecretModel { s | allowCommand = yesNoToBool allow } secretsModel

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
                [ div [ class "add-secret" ]
                    [ div []
                        [ Html.h2 [] [ text "Update Secrets" ]
                        , secretForm secretsModel secrets
                        ]
                    ]
                , viewSecrets secrets
                ]

        _ ->
            div [] [ largeLoader ]


secretForm : Args msg -> Secrets -> Html Msg
secretForm secretsModel secrets =
    div []
        [ selectSecret secretsModel secrets
        , case secretsModel.manageState of
            Add ->
                addSecret secretsModel

            Update ->
                div [] [ text "update secret" ]

            Choose ->
                text ""
        ]


addSecret : Args msg -> Html Msg
addSecret secretsModel =
    let
        secretUpdate =
            secretsModel.secretAdd
    in
    div [ class "secret-form" ]
        [ Html.h4 [ class "field-header" ] [ text "Name" ]
        , nameInput secretsModel.secretAdd.name False
        , Html.h4 [ class "field-header" ] [ text "Value" ]
        , valueInput secretUpdate.value
        , typeSelect secretUpdate
        , teamInput secretUpdate
        , eventsSelect secretUpdate
        , imagesInput secretUpdate secretUpdate.imageInput
        , allowCommandCheckbox secretUpdate
        , help
        , div [ class "-m-t" ]
            [ Html.button [ class "button", class "-outline", onClick AddSecret ] [ text "Add" ]
            , Html.button
                [ class "-m-l"
                , class "button"
                , class "-outline"
                , onClick CancelUpdate
                ]
                [ text "Cancel" ]
            ]
        ]


viewSecrets : Secrets -> Html Msg
viewSecrets secrets =
    div [ class "secrets-table", class "table" ] <| secretsTable secrets


{-| secretsTable : renders secrets table
-}
secretsTable : Secrets -> List (Html Msg)
secretsTable secrets =
    [ div [ class "table-label" ] [ text "Secrets" ], headers ]
        ++ (if List.length secrets > 0 then
                rows secrets

            else
                [ div [ class "no-secrets" ] [ text "No secrets found for this repository" ] ]
           )


{-| headers : renders secrets table headers
-}
headers : Html Msg
headers =
    div [ class "headers" ]
        [ div [ class "header" ] [ text "name" ]
        , div [ class "header" ] [ text "type" ]
        , div [ class "header" ] [ text "events" ]
        , div [ class "header" ] [ text "images" ]
        , div [ class "header" ] [ text "allow commands" ]
        ]


{-| rows : renders secrets table rows
-}
rows : Secrets -> List (Html Msg)
rows secrets =
    List.map (\secret -> row secret) secrets


{-| row : renders hooks table row wrapped in details element
-}
row : Secret -> Html Msg
row secret =
    div [ class "details", class "-no-pad", Util.testAttribute "secret" ]
        [ div [ class "secrets-row" ]
            [ preview secret ]
        ]


{-| preview : renders the hook preview displayed as the clickable row
-}
preview : Secret -> Html Msg
preview secret =
    div [ class "row", class "preview" ]
        [ cell secret.name <| class "host"
        , cell (secretTypeToString secret.type_) <| class ""
        , arrayCell secret.events "no events"
        , arrayCell secret.images "no images"
        , cell (boolToYesNo secret.allowCommand) <| class ""
        ]


{-| cell : takes text and maybe attributes and renders cell data for hooks table row
-}
cell : String -> Html.Attribute Msg -> Html Msg
cell txt cls =
    div [ class "cell", cls ]
        [ span [] [ text txt ] ]


arrayCell : List String -> String -> Html Msg
arrayCell images default =
    div [ class "cell" ] <|
        List.intersperse (text ",") <|
            if List.length images > 0 then
                List.map (\image -> code [ class "text", class "-m-l" ] [ text image ]) images

            else
                [ code [ class "text" ] [ text default ] ]


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


secretsToOptions : Secrets -> List (Html Msg)
secretsToOptions secrets =
    defaultOptions ++ List.map secretToOption secrets


secretToOption : Secret -> Html Msg
secretToOption secret =
    Html.option [ value <| String.fromInt secret.id ] [ text secret.name ]


defaultOptions : List (Html Msg)
defaultOptions =
    [ Html.option [ value "default" ]
        [ text "Select Secret" ]
    , Html.option [ value "new" ] [ text "<NEW SECRET>" ]
    ]


nameInput : String -> Bool -> Html Msg
nameInput val disable =
    div [] [ Html.input [ disabled disable, value val, onInput <| OnChangeStringField "name", class "secret-name", Html.Attributes.placeholder "Secret Name" ] [] ]


valueInput : String -> Html Msg
valueInput val =
    div [] [ Html.textarea [ value val, onInput <| OnChangeStringField "value", class "secret-value", Html.Attributes.placeholder "Secret Value" ] [] ]


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


eventsSelect : SecretUpdate -> Html Msg
eventsSelect secretUpdate =
    Html.section [ class "events", Util.testAttribute "" ]
        [ Html.h4 [ class "field-header" ] [ text "Limit to Events" ]
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
                ]
                [ text "Add Image"
                ]
            ]
        , div [ class "images" ] <| List.map addedImage secret.images
        ]


addedImage : String -> Html Msg
addedImage image =
    div [ class "added-image" ]
        [ div [ class "name" ] [ text image ]
        , Html.button
            [ class "button"
            , class "-outline"
            , class "-slim"
            , onClick <| RemoveImage image
            ]
            [ text "remove"
            ]
        ]


allowCommandCheckbox : SecretUpdate -> Html Msg
allowCommandCheckbox secretUpdate =
    section [ class "type", Util.testAttribute "" ]
        [ h4 [ class "field-header" ]
            [ text "Allow Commands"
            , span [ class "field-description" ]
                [ em [] [ text "(\"No\" will disable this secret in " ]
                , span [ class "-code" ] [ text "commands" ]
                , em [] [ text ")" ]
                ]
            ]
        , div
            [ class "form-controls", class "-row" ]
            [ radio (boolToYesNo secretUpdate.allowCommand) "yes" "Yes" <| OnChangeAllowCommand "yes"
            , radio (boolToYesNo secretUpdate.allowCommand) "no" "No" <| OnChangeAllowCommand "no"
            ]
        ]


help : Html Msg
help =
    div [] [ text "Need help? Visit our ", a [] [ text "docs" ], text "!" ]



-- HELPERS


getKey : Args msg -> SecretUpdate -> String
getKey secretsModel secret =
    case secret.type_ of
        Vela.Repo ->
            secretsModel.repo

        Vela.Org ->
            "*"

        Vela.Shared ->
            secret.team


toAddSecretPayload : Args msg -> SecretUpdate -> AddSecretPayload
toAddSecretPayload secretsModel secret =
    let
        args =
            case secret.type_ of
                Vela.Repo ->
                    { type_ = secret.type_, repo = Just secretsModel.repo, team = Nothing }

                Vela.Org ->
                    { type_ = Vela.Org, repo = Just "*", team = Nothing }

                Vela.Shared ->
                    { type_ = Vela.Org, repo = Nothing, team = Just secret.team }
    in
    buildAddSecretPayload args.type_ secretsModel.org args.repo args.team secret.name secret.value secret.events secret.images secret.allowCommand


handleSelection : String -> ManageSecretState
handleSelection selection =
    case selection of
        "default" ->
            Choose

        "new" ->
            Add

        _ ->
            Update


getSelectedSecret : Args msg -> Maybe Secret
getSelectedSecret secretModel =
    Util.getById (Maybe.withDefault 0 <| String.toInt secretModel.selectedSecret) <|
        case secretModel.secrets of
            Success s ->
                s

            _ ->
                []


eventEnabled : String -> List String -> Bool
eventEnabled event =
    List.member event


toggleEvent : String -> List String -> List String
toggleEvent event events =
    if List.member event events then
        List.Extra.remove event events

    else
        event :: events


boolToYesNo : Bool -> String
boolToYesNo bool =
    if bool then
        "yes"

    else
        "no"


yesNoToBool : String -> Bool
yesNoToBool yesNo =
    yesNo == "yes"



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
                        , manageState = handleSelection selection
                      }
                    , Cmd.none
                    )

                CancelUpdate ->
                    ( { secretsModel
                        | selectedSecret = "default"
                        , manageState = handleSelection "default"
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

                AddSecret ->
                    let
                        secret =
                            secretsModel.secretAdd

                        payload : AddSecretPayload
                        payload =
                            toAddSecretPayload secretsModel secretsModel.secretAdd

                        body : Http.Body
                        body =
                            Http.jsonBody <| encodeAddSecret payload
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
                    -- let
                    --     payload : UpdateSecretPayload
                    --     payload =
                    --         UpdateSecretPayload Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
                    --     body : Http.Body
                    --     body =
                    --         Http.jsonBody <| encodeUpdateSecret payload
                    -- in
                    -- ( args, Api.try args.secretResponse <| Api.updateSecret model type_ org key name body )
                    ( secretsModel, Cmd.none )

                NoOp ->
                    ( secretsModel, Cmd.none )
    in
    ( { model | secretsModel = sm }, action )
