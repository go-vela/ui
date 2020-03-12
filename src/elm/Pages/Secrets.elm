{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets exposing (Msg, init, update, view)

import Api
import Html
    exposing
        ( Html
        , code
        , div
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
        ( Key
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
        , buildUpdateSecretPayload
        , encodeUpdateSecret
        , secretTypeToString
        , toSecretType
        )


init =
    ""


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
    , secretResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Secret ) -> msg
    , secretsResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ) -> msg
    }


type Msg
    = OnChangeStringField String String
    | SelectSecret String
    | OnChangeEvent String Bool
    | AddImage String
    | RemoveImage String
    | OnChangeAllowCommand Bool
    | CancelUpdate
    | AddSecret
    | UpdateSecret Type Org Key Name
    | NoOp


type ManageSecretState
    = Choose
    | Add
    | Update


type alias SecretUpdate =
    { org : Org
    , repo : Repo
    , team : Team
    , name : String
    , value : String
    , type_ : SecretType
    , events : List String
    , imageInput : String
    , images : List String
    , allowCommand : Bool
    }


onChangeStringField : String -> String -> Args msg -> Args msg
onChangeStringField field value secretsModel =
    case secretsModel.manageState of
        Add ->
            let
                secretAdd =
                    secretsModel.secretAdd
            in
            { secretsModel | secretAdd = updateSecretField field value secretAdd }

        Update ->
            secretsModel

        Choose ->
            secretsModel


updateSecretField : String -> String -> SecretUpdate -> SecretUpdate
updateSecretField field value secret =
    case field of
        "team" ->
            { secret | team = value }

        "name" ->
            { secret | imageInput = value }

        "value" ->
            { secret | imageInput = value }

        "imageInput" ->
            { secret | imageInput = value }

        _ ->
            secret



-- VIEW


{-| view : takes model and renders page for managing repo secrets
-}
view : PartialModel a msg -> Html Msg
view model =
    case model.secretsModel.secrets of
        Success s ->
            div []
                [ secretForm
                , viewSecrets s
                ]

        _ ->
            div [] [ largeLoader ]


secretForm : Html Msg
secretForm =
    div [] []


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
selectSecret args secrets =
    div []
        [ Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Secret" ]
        , Html.select
            [ class "select-secret"
            , value args.selectedSecret
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
typeSelect args =
    Html.section [ class "type", Util.testAttribute "" ]
        [ Html.h4 [ class "-no-pad" ] [ text "Type" ]
        , div
            [ class "form-controls", class "-row" ]
            [ radio (secretTypeToString args.type_) "repo" "Repo" <| OnChangeStringField "type" "repo"
            , radio (secretTypeToString args.type_) "org" "Org (current org)" <| OnChangeStringField "type" "org"
            , radio (secretTypeToString args.type_) "shared" "Shared" <| OnChangeStringField "type" "shared"
            ]
        ]


teamInput : SecretUpdate -> Html Msg
teamInput secret =
    case secret.type_ of
        Vela.Shared ->
            div []
                [ Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Team" ]
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
        [ Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Limit to Events" ]
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
imagesInput args imageInput =
    Html.section [ class "image", Util.testAttribute "" ]
        [ Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Limit to Docker Images" ]
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
        , div [ class "images" ] <| List.map addedImage args.images
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



-- HELPERS


getSecretAddKey : SecretUpdate -> String
getSecretAddKey secretAdd =
    case secretAdd.type_ of
        Vela.Repo ->
            secretAdd.repo

        Vela.Org ->
            "*"

        Vela.Shared ->
            secretAdd.team


getSecretUpdateKey : SecretUpdate -> String
getSecretUpdateKey secretUpdate =
    case secretUpdate.type_ of
        Vela.Repo ->
            secretUpdate.repo

        Vela.Org ->
            "*"

        Vela.Shared ->
            secretUpdate.team


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
getSelectedSecret args =
    Util.getById (Maybe.withDefault 0 <| String.toInt args.selectedSecret) <|
        case args.secrets of
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



-- UPDATE


update : PartialModel a msg -> Msg -> ( PartialModel a msg, Cmd msg )
update model msg =
    let
        secretsModel =
            model.secretsModel

        secretAdd =
            secretsModel.secretAdd

        secretUpdate =
            secretsModel.secretUpdate

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
                    -- ( { secretsModel | newSecret = { newSecret | events = toggleEvent event newSecret.events } }, Cmd.none )
                    ( secretsModel, Cmd.none )

                AddImage image ->
                    -- ( { secretsModel | newSecret = { newSecret | images = Util.filterEmptyList <| List.Extra.unique <| image :: newSecret.images } }, Cmd.none )
                    ( secretsModel, Cmd.none )

                RemoveImage image ->
                    -- ( { secretsModel | newSecret = { newSecret | images = List.Extra.remove image newSecret.images } }, Cmd.none )
                    ( secretsModel, Cmd.none )

                OnChangeAllowCommand allow ->
                    -- ( { secretsModel | newSecret = { newSecret | allowCommand = allow } }, Cmd.none )
                    ( secretsModel, Cmd.none )

                AddSecret ->
                    ( secretsModel, Cmd.none )

                -- let
                --     key =
                --         getKey secretsModel
                --     payload : UpdateSecretPayload
                --     payload =
                --         buildAddSecretPayload newSecret
                --     body : Http.Body
                --     body =
                --         Http.jsonBody <| encodeUpdateSecret payload
                -- in
                -- ( args, Api.try args.secretResponse <| Api.addSecret model (secretTypeToString newSecret.type_) args.org key body )
                UpdateSecret type_ org key name ->
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
