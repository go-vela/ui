{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.RepoSecrets exposing (Args, Msg, Msgs, SelectSecret, init, toggleUpdateSecret, update, view)

import FeatherIcons
import Html
    exposing
        ( Html
        , code
        , details
        , div
        , span
        , summary
        , text
        )
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import List.Extra
import Pages exposing (Page(..))
import Pages.RepoSettings exposing (checkbox, radio)
import RemoteData exposing (RemoteData(..), WebData)
import Svg.Attributes
import Util exposing (largeLoader)
import Vela
    exposing
        ( Secret
        , Secrets
        )


type alias AddSecret msg =
    Maybe Bool -> msg


type alias SelectSecret msg =
    String -> msg


{-| Msgs : record for routing msg updates to Main.elm
-}
type alias Msgs msg =
    { showHideUpdateSecret : AddSecret msg
    , onInput : SelectSecret msg
    }


type Msg
    = SelectSecret String
    | OnChangeName String
    | OnChangeValue String
    | OnChangeType String
    | OnChangeEvent String Bool
    | AddImage String
    | RemoveImage String
    | OnChangeImageInput String
    | CancelUpdate
    | NoOp


type alias Args =
    { secrets : WebData Secrets
    , showUpdateSecret : Bool
    , manageState : ManageSecretState
    , selectedSecret : String
    , newSecret : NewSecret
    }


type alias NewSecret =
    { name : String
    , value : String
    , type_ : String
    , imageInput : String
    , images : List String
    , events : Events
    }


defaultNewSecret : NewSecret
defaultNewSecret =
    NewSecret "" "" "repo" "" [] defaultEvents


type alias Events =
    { push : Bool
    , pull : Bool
    , deploy : Bool
    , tag : Bool
    }


defaultEvents : Events
defaultEvents =
    Events True False False False


init : Args
init =
    Args NotAsked False ChooseSecret "default" defaultNewSecret



-- updateNewSecret : NewSecret -> { a | type_ : String } -> NewSecret
-- updateNewSecret args s =
--     { args | s }


update : Args -> Msg -> Args
update args msg =
    let
        newSecret =
            args.newSecret
    in
    case msg of
        SelectSecret selection ->
            { args
                | selectedSecret = selection
                , manageState = handleSelection selection
            }

        CancelUpdate ->
            { args
                | selectedSecret = "default"
                , manageState = handleSelection "default"
            }

        OnChangeName name ->
            { args | newSecret = { newSecret | name = name } }

        OnChangeValue value ->
            { args | newSecret = { newSecret | value = value } }

        OnChangeType type_ ->
            { args | newSecret = { newSecret | type_ = type_ } }

        OnChangeEvent event _ ->
            { args | newSecret = { newSecret | events = toggleEvent event newSecret.events } }

        OnChangeImageInput input ->
            { args | newSecret = { newSecret | imageInput = input } }

        AddImage image ->
            { args | newSecret = { newSecret | images = Util.filterEmptyList <| List.Extra.unique <| image :: newSecret.images } }

        RemoveImage image ->
            { args | newSecret = { newSecret | images = List.Extra.remove image newSecret.images } }

        NoOp ->
            args


handleSelection : String -> ManageSecretState
handleSelection selection =
    case selection of
        "default" ->
            ChooseSecret

        "new" ->
            AddSecret

        _ ->
            UpdateSecret


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


type ManageSecretState
    = ChooseSecret
    | AddSecret
    | UpdateSecret


manageSecret : Args -> Secrets -> Html Msg
manageSecret args secrets =
    let
        content =
            case args.manageState of
                ChooseSecret ->
                    div [] [ selectSecret args secrets ]

                AddSecret ->
                    div []
                        [ selectSecret args secrets
                        , div [ class "new-secret" ]
                            [ div [] [ Html.input [ class "secret-name", Html.Attributes.placeholder "Secret Name" ] [] ]
                            , div [] [ Html.textarea [ class "secret-value", Html.Attributes.placeholder "Secret Value" ] [] ]
                            , secretType args.newSecret
                            , secretEvents args.newSecret
                            , secretImages args.newSecret
                            ]
                        , div []
                            [ Html.button [ class "button", class "-outline" ] [ text "Add" ]
                            , Html.button
                                [ class "-m-l"
                                , class "button"
                                , class "-outline"
                                , onClick CancelUpdate
                                ]
                                [ text "Cancel" ]
                            ]
                        ]

                UpdateSecret ->
                    div []
                        [ selectSecret args secrets
                        , div [] [ Html.textarea [ class "secret-value", Html.Attributes.placeholder "Secret Value" ] [] ]
                        , div [] [ Html.button [ class "button", class "-outline" ] [ text "Update" ], Html.button [ class "-m-l", class "button", class "-outline" ] [ text "Cancel" ] ]
                        ]
    in
    div [ class "add-secret" ]
        [ div [] [ Html.h2 [] [ text "Update Secrets" ] ]
        , content
        ]


secretType : NewSecret -> Html Msg
secretType args =
    Html.section [ class "secret-type", Util.testAttribute "" ]
        [ Html.h4 [ class "-no-pad" ] [ text "Type" ]
        , div
            [ class "form-controls", class "-row" ]
            [ radio args.type_ "repo" "Repo" <| OnChangeType "repo"
            , radio args.type_ "org" "Org" <| OnChangeType "org"
            , radio args.type_ "shared" "Shared" <| OnChangeType "shared"
            ]
        ]


secretEvents : NewSecret -> Html Msg
secretEvents args =
    Html.section [ class "secret-type", Util.testAttribute "" ]
        [ Html.h4 [ class "-no-pad" ] [ text "Limit to Events" ]
        , div [ class "form-controls" ]
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


secretImages : NewSecret -> Html Msg
secretImages args =
    Html.section [ class "secret-type", Util.testAttribute "" ]
        [ Html.h4 [ class "-no-pad" ] [ text "Limit to Docker Images" ]
        , div []
            [ Html.input
                [ class "secret-name"
                , Html.Attributes.placeholder "Image Name"
                , Html.Events.onInput OnChangeImageInput
                ]
                []
            , Html.button
                [ class "button"
                , class "-icon"
                , onClick <| AddImage <| String.toLower args.imageInput
                ]
                [ FeatherIcons.plusCircle
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml [ Svg.Attributes.class "add" ]
                ]
            ]
        , div [] <| List.map addedImage args.images
        ]


addedImage : String -> Html Msg
addedImage image =
    div [ class "added-image" ]
        [ code [] [ text image ]
        , Html.button
            [ class "button"
            , class "-icon"
            , onClick <| RemoveImage image
            ]
            [ FeatherIcons.trash
                |> FeatherIcons.withSize 18
                |> FeatherIcons.toHtml [ Svg.Attributes.class "trash" ]
            ]
        ]


selectSecret : Args -> Secrets -> Html Msg
selectSecret args secrets =
    div []
        [ Html.select
            [ class "select-secret"
            , Html.Attributes.value args.selectedSecret
            , Html.Events.onInput SelectSecret
            ]
          <|
            secretsToOptions secrets
        ]


secretsToOptions : Secrets -> List (Html Msg)
secretsToOptions secrets =
    defaultOptions ++ List.map secretToOption secrets


secretToOption : Secret -> Html Msg
secretToOption secret =
    Html.option [ Html.Attributes.value <| String.fromInt secret.id ] [ text secret.name ]


defaultOptions : List (Html Msg)
defaultOptions =
    [ Html.option [ Html.Attributes.value "default" ]
        [ text "Select Secret" ]
    , Html.option [ Html.Attributes.value "new" ] [ text "<NEW SECRET>" ]
    ]


toggleUpdateSecret : Args -> Maybe Bool -> Args
toggleUpdateSecret args show =
    case show of
        Just s ->
            { args | showUpdateSecret = s }

        Nothing ->
            { args | showUpdateSecret = not args.showUpdateSecret }


{-| view : takes model and renders page for managing repo secrets
-}
view : Args -> Html Msg
view args =
    let
        content =
            case args.secrets of
                Success s ->
                    if List.length s > 0 then
                        div []
                            [ manageSecret args s
                            , viewSecrets s
                            ]

                    else
                        div [] [ text "no secrets found for this repository" ]

                _ ->
                    div [] [ largeLoader ]
    in
    -- div [] [ div [ class "header" ] [ Html.h2 [] [ text "Secrets" ] ], content ]
    content


viewSecrets : Secrets -> Html Msg
viewSecrets secrets =
    div [ class "table" ] <| secretsTable secrets


{-| secretsTable : renders secrets table
-}
secretsTable : Secrets -> List (Html Msg)
secretsTable secrets =
    headers :: rows secrets


{-| headers : renders secrets table headers
-}
headers : Html Msg
headers =
    div [ class "headers" ]
        [ div [ class "secrets-first-cell", class "-label" ] [ text "Secrets" ]
        , div [ class "header" ] [ text "name" ]
        , div [ class "header" ] [ text "type" ]
        , div [ class "header" ] [ text "events" ]
        , div [ class "header" ] [ text "images" ]

        -- , div [ class "header", Html.Attributes.style "color" "var(--color-primary)" ] [ Html.button [ class "button", class "-outline", class "-slim" ] [ text "add secret" ] ]
        -- , div [ class "header", class "-last" ] [ div [ class "-inner" ] [ Html.button [ class "button", class "-outline" ] [ text "Add Secret" ] ] ]
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
    div [ class "details", class "-no-pad", Util.testAttribute "hook" ]
        [ div [ class "secrets-row" ]
            [ preview secret ]
        ]


{-| preview : renders the hook preview displayed as the clickable row
-}
preview : Secret -> Html Msg
preview secret =
    div [ class "row", class "preview" ]
        [ firstCell
        , cell secret.name <| class "host"
        , cell secret.type_ <| class ""
        , arrayCell secret.events "no events"
        , arrayCell secret.images "no images"

        -- , lastCell msgs
        ]


{-| firstCell : renders the expansion chevron icon
-}
firstCell : Html Msg
firstCell =
    div [ class "filler-cell" ]
        []


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
