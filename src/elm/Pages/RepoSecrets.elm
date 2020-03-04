{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.RepoSecrets exposing (Args, Msgs, init, toggleUpdateSecret, view)

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
import Pages exposing (Page(..))
import RemoteData exposing (RemoteData(..), WebData)
import Util exposing (largeLoader)
import Vela
    exposing
        ( Secret
        , Secrets
        )


type alias AddSecret msg =
    Maybe Bool -> msg


{-| Msgs : record for routing msg updates to Main.elm
-}
type alias Msgs msg =
    { showHideUpdateSecret : AddSecret msg
    }


type alias Args =
    { secrets : WebData Secrets
    , showUpdateSecret : Bool
    }


toggleUpdateSecret : Args -> Maybe Bool -> Args
toggleUpdateSecret args show =
    case show of
        Just s ->
            { args | showUpdateSecret = s }

        Nothing ->
            { args | showUpdateSecret = not args.showUpdateSecret }


init : Args
init =
    Args NotAsked False


{-| view : takes model and renders page for managing repo secrets
-}
view : Args -> Msgs msg -> Html msg
view args msgs =
    let
        content =
            case args.secrets of
                Success s ->
                    if List.length s > 0 then
                        div []
                            [ if args.showUpdateSecret then
                                addSecret msgs.showHideUpdateSecret

                              else
                                text ""
                            , viewSecrets s msgs
                            ]

                    else
                        div [] [ text "no secrets found for this repository" ]

                _ ->
                    div [] [ largeLoader ]
    in
    -- div [] [ div [ class "header" ] [ Html.h2 [] [ text "Secrets" ] ], content ]
    content


addSecret : (Maybe Bool -> msg) -> Html msg
addSecret showHideUpdateSecret =
    div [ class "add-secret" ]
        [ div [] [ Html.h2 [] [ text "Add Secret" ] ]
        , div [] [ Html.input [ class "secret-name", Html.Attributes.placeholder "Secret Name" ] [] ]
        , div [] [ Html.textarea [ class "secret-value", Html.Attributes.placeholder "Secret Value" ] [] ]
        , div [] [ Html.button [ class "button", class "-outline" ] [ text "Add" ], Html.button [ class "-m-l", class "button", class "-outline", onClick <| showHideUpdateSecret <| Just False ] [ text "Cancel" ] ]
        ]


viewSecrets : Secrets -> Msgs msg -> Html msg
viewSecrets secrets msgs =
    div [ class "table" ] <| secretsTable secrets msgs


{-| secretsTable : renders secrets table
-}
secretsTable : Secrets -> Msgs msg -> List (Html msg)
secretsTable secrets msgs =
    headers :: rows secrets msgs


{-| headers : renders secrets table headers
-}
headers : Html msg
headers =
    div [ class "headers" ]
        [ div [ class "secrets-first-cell", class "-label" ] [ text "Secrets" ]
        , div [ class "header" ] [ text "name" ]
        , div [ class "header" ] [ text "type" ]
        , div [ class "header" ] [ text "events" ]
        , div [ class "header" ] [ text "images" ]
        , div [ class "header", Html.Attributes.style "color" "var(--color-primary)" ] [ Html.button [ class "button", class "-outline", class "-slim" ] [ text "add secret" ] ]

        -- , div [ class "header", class "-last" ] [ div [ class "-inner" ] [ Html.button [ class "button", class "-outline" ] [ text "Add Secret" ] ] ]
        ]


{-| rows : renders secrets table rows
-}
rows : Secrets -> Msgs msg -> List (Html msg)
rows secrets msgs =
    List.map (\secret -> row secret msgs) secrets


{-| row : renders hooks table row wrapped in details element
-}
row : Secret -> Msgs msg -> Html msg
row secret msgs =
    div [ class "details", class "-no-pad", Util.testAttribute "hook" ]
        [ div [ class "secrets-row" ]
            [ preview secret msgs ]
        ]


{-| preview : renders the hook preview displayed as the clickable row
-}
preview : Secret -> Msgs msg -> Html msg
preview secret msgs =
    div [ class "row", class "preview" ]
        [ firstCell
        , cell secret.name <| class "host"
        , cell secret.type_ <| class ""
        , arrayCell secret.events "no events"
        , arrayCell secret.images "no images"
        , lastCell msgs
        ]


{-| firstCell : renders the expansion chevron icon
-}
firstCell : Html msg
firstCell =
    div [ class "filler-cell" ]
        []


{-| cell : takes text and maybe attributes and renders cell data for hooks table row
-}
cell : String -> Html.Attribute msg -> Html msg
cell txt cls =
    div [ class "cell", cls ]
        [ span [] [ text txt ] ]


arrayCell : List String -> String -> Html msg
arrayCell images default =
    div [ class "cell" ] <|
        List.intersperse (text ",") <|
            if List.length images > 0 then
                List.map (\image -> code [ class "text", class "-m-l" ] [ text image ]) images

            else
                [ code [ class "text" ] [ text default ] ]


lastCell : Msgs msg -> Html msg
lastCell msgs =
    div [ class "cell" ] [ Html.button [ class "button", class "-outline", class "-slim", onClick <| msgs.showHideUpdateSecret Nothing ] [ text "Edit" ] ]


{-| info : renders the table row details when clicking/expanding a row
-}
info : Secret -> Html msg
info secret =
    div [ class "update-secret" ]
        [ div []
            [ text "Update Secret "
            , Html.code [ class "text" ] [ text secret.name ]
            ]
        , Html.textarea [ Html.Attributes.placeholder "Secret Value" ] []
        , div [] [ Html.button [ class "button", class "-outline" ] [ text "Update" ] ]
        ]


viewSecret : Secret -> Html msg
viewSecret secret =
    div [] [ text secret.name ]
