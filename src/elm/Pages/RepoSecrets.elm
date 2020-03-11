{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.RepoSecrets exposing (Args, Msg, SelectSecret, defaultSecretUpdate, init, toggleUpdateSecret, update, view)

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


type alias SelectSecret msg =
    String -> msg


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | velaAPI : String
        , session : Maybe Session
    }


type Msg
    = SelectSecret String
    | OnChangeName String
    | OnChangeValue String
    | OnChangeType String
    | OnChangeTeam String
    | OnChangeEvent String Bool
    | AddImage String
    | RemoveImage String
    | OnChangeImageInput String
    | OnChangeAllowCommand Bool
    | CancelUpdate
    | AddSecret
    | UpdateSecret Type Org Key Name
    | NoOp


type alias Args msg =
    { org : Org
    , repo : Repo
    , secrets : WebData Secrets
    , showUpdateSecret : Bool
    , manageState : ManageSecretState
    , selectedSecret : String
    , imageInput : String
    , newSecret : SecretUpdate
    , secretResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Secret ) -> msg
    , secretsResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ) -> msg
    }


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
    , events : Events
    , images : List String
    , allowCommand : Bool
    }


defaultSecretUpdate : SecretUpdate
defaultSecretUpdate =
    SecretUpdate "" "" "" "" "" Vela.Repo defaultEvents [] True


type alias Events =
    { push : Bool
    , pull : Bool
    , deploy : Bool
    , tag : Bool
    }


defaultEvents : Events
defaultEvents =
    Events True False False False


eventsToMaybeList : Events -> Maybe (List String)
eventsToMaybeList { push, pull, deploy, tag } =
    let
        events =
            List.filterMap
                (\( a, b ) ->
                    if a then
                        Just b

                    else
                        Nothing
                )
                [ ( push, "push" ), ( pull, "pull" ), ( deploy, "deploy" ), ( tag, "tag" ) ]
    in
    if List.length events > 0 then
        Just events

    else
        Nothing


init :
    (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ) -> msg)
    -> (Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ) -> msg)
    -> Args msg
init secretMsg secretsMsg =
    Args "" "" NotAsked False Choose "default" "" defaultSecretUpdate secretMsg secretsMsg


update : Args msg -> PartialModel a -> Msg -> ( Args msg, Cmd msg )
update args model msg =
    let
        newSecret =
            args.newSecret
    in
    case msg of
        SelectSecret selection ->
            ( { args
                | selectedSecret = selection
                , manageState = handleSelection selection
              }
            , Cmd.none
            )

        CancelUpdate ->
            ( { args
                | selectedSecret = "default"
                , manageState = handleSelection "default"
              }
            , Cmd.none
            )

        OnChangeName name ->
            ( { args | newSecret = { newSecret | name = name } }, Cmd.none )

        OnChangeValue value ->
            ( { args | newSecret = { newSecret | value = value } }, Cmd.none )

        OnChangeType type_ ->
            ( { args | newSecret = { newSecret | type_ = toSecretType type_ } }, Cmd.none )

        OnChangeTeam team ->
            ( { args | newSecret = { newSecret | team = team } }, Cmd.none )

        OnChangeEvent event _ ->
            ( { args | newSecret = { newSecret | events = toggleEvent event newSecret.events } }, Cmd.none )

        OnChangeImageInput input ->
            ( { args | imageInput = input }, Cmd.none )

        AddImage image ->
            ( { args | newSecret = { newSecret | images = Util.filterEmptyList <| List.Extra.unique <| image :: newSecret.images } }, Cmd.none )

        RemoveImage image ->
            ( { args | newSecret = { newSecret | images = List.Extra.remove image newSecret.images } }, Cmd.none )

        OnChangeAllowCommand allow ->
            ( { args | newSecret = { newSecret | allowCommand = allow } }, Cmd.none )

        AddSecret ->
            let
                key =
                    getKey args

                payload : UpdateSecretPayload
                payload =
                    buildAddSecretPayload newSecret

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateSecret payload
            in
            ( args, Api.try args.secretResponse <| Api.addSecret model (secretTypeToString newSecret.type_) args.org key body )

        UpdateSecret type_ org key name ->
            let
                payload : UpdateSecretPayload
                payload =
                    UpdateSecretPayload Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateSecret payload
            in
            ( args, Api.try args.secretResponse <| Api.updateSecret model type_ org key name body )

        NoOp ->
            ( args, Cmd.none )


getKey : Args msg -> String
getKey args =
    case args.newSecret.type_ of
        Vela.Repo ->
            args.repo

        Vela.Org ->
            args.newSecret.team

        Vela.Shared ->
            args.newSecret.team


buildAddSecretPayload : SecretUpdate -> UpdateSecretPayload
buildAddSecretPayload secret =
    let
        ( org, repo, team ) =
            case secret.type_ of
                Vela.Repo ->
                    ( Just secret.org, Just secret.repo, Nothing )

                Vela.Org ->
                    ( Just secret.org, Just "*", Nothing )

                Vela.Shared ->
                    ( Just secret.org, Nothing, Just secret.team )
    in
    buildUpdateSecretPayload (Just secret.type_)
        org
        repo
        team
        (Just secret.name)
        (Just secret.value)
        (eventsToMaybeList secret.events)
        (Just secret.images)
        (Just secret.allowCommand)


handleSelection : String -> ManageSecretState
handleSelection selection =
    case selection of
        "default" ->
            Choose

        "new" ->
            Add

        _ ->
            Update


toggleEvent : String -> Events -> Events
toggleEvent event events =
    case event of
        "push" ->
            { events | push = not events.push }

        "pull" ->
            { events | pull = not events.pull }

        "deploy" ->
            { events | deploy = not events.deploy }

        "tag" ->
            { events | tag = not events.tag }

        _ ->
            events


getSelectedSecret : Args msg -> Maybe Secret
getSelectedSecret args =
    Util.getById (Maybe.withDefault 0 <| String.toInt args.selectedSecret) <|
        case args.secrets of
            Success s ->
                s

            _ ->
                []


manageSecret : Args msg -> Secrets -> Html Msg
manageSecret args secrets =
    let
        content =
            case args.manageState of
                Choose ->
                    div [] [ selectSecret args secrets ]

                Add ->
                    div []
                        [ selectSecret args secrets
                        , div [ class "new-secret" ]
                            [ Html.h4 [ class "subheader" ] [ text "Add a New Secret" ]
                            , Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Name" ]
                            , nameInput args.newSecret.name False
                            , Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Value" ]
                            , valueInput args.newSecret.value
                            , typeSelect args.newSecret
                            , teamInput args.newSecret
                            , eventsSelect args.newSecret
                            , imagesInput args.newSecret args.imageInput
                            ]
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

                Update ->
                    let
                        secret_ =
                            getSelectedSecret args

                        updateSecret =
                            case secret_ of
                                Just s ->
                                    [ div [ class "new-secret" ]
                                        [ Html.h4 [ class "subheader" ] [ text "Update Existing Secret" ]
                                        , Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Name" ]
                                        , nameInput s.name True
                                        , Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Value" ]
                                        , valueInput args.newSecret.value
                                        , typeSelect args.newSecret
                                        , teamInput args.newSecret
                                        , eventsSelect args.newSecret
                                        , imagesInput args.newSecret args.imageInput
                                        ]
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

                                Nothing ->
                                    [ div [] [ text "There was a problem fetching this secret.... refresh the page and try again!" ] ]
                    in
                    div [] <|
                        selectSecret args secrets
                            :: updateSecret
    in
    div [ class "add-secret" ]
        [ div [] [ Html.h2 [] [ text "Update Secrets" ] ]
        , content
        ]


nameInput : String -> Bool -> Html Msg
nameInput val disable =
    div [] [ Html.input [ disabled disable, value val, onInput OnChangeName, class "secret-name", Html.Attributes.placeholder "Secret Name" ] [] ]


valueInput : String -> Html Msg
valueInput val =
    div [] [ Html.textarea [ value val, onInput OnChangeValue, class "secret-value", Html.Attributes.placeholder "Secret Value" ] [] ]


typeSelect : SecretUpdate -> Html Msg
typeSelect args =
    Html.section [ class "type", Util.testAttribute "" ]
        [ Html.h4 [ class "-no-pad" ] [ text "Type" ]
        , div
            [ class "form-controls", class "-row" ]
            [ radio (secretTypeToString args.type_) "repo" "Repo" <| OnChangeType "repo"
            , radio (secretTypeToString args.type_) "org" "Org (current org)" <| OnChangeType "org"
            , radio (secretTypeToString args.type_) "shared" "Shared" <| OnChangeType "shared"
            ]
        ]


teamInput : SecretUpdate -> Html Msg
teamInput secret =
    case secret.type_ of
        Vela.Shared ->
            div []
                [ Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Team" ]
                , div [] [ Html.textarea [ value secret.team, onInput OnChangeTeam, class "team-value", Html.Attributes.placeholder "Team Name" ] [] ]
                ]

        _ ->
            text ""


eventsSelect : SecretUpdate -> Html Msg
eventsSelect args =
    Html.section [ class "events", Util.testAttribute "" ]
        [ Html.h4 [ class "-no-pad", class "-m-t" ] [ text "Limit to Events" ]
        , div [ class "form-controls", class "-row" ]
            [ checkbox "Push"
                "push"
                args.events.push
              <|
                OnChangeEvent "push"
            , checkbox "Pull Request"
                "pull"
                args.events.pull
              <|
                OnChangeEvent "pull"
            , checkbox "Deploy"
                "deploy"
                args.events.deploy
              <|
                OnChangeEvent "deploy"
            , checkbox "Tag"
                "tag"
                args.events.tag
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
                , onInput OnChangeImageInput
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


toggleUpdateSecret : Args msg -> Maybe Bool -> Args msg
toggleUpdateSecret args show =
    case show of
        Just s ->
            { args | showUpdateSecret = s }

        Nothing ->
            { args | showUpdateSecret = not args.showUpdateSecret }


{-| view : takes model and renders page for managing repo secrets
-}
view : Args msg -> Html Msg
view args =
    case args.secrets of
        Success s ->
            div []
                [ manageSecret args s
                , viewSecrets s
                ]

        _ ->
            div [] [ largeLoader ]


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
