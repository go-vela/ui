{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.RepoSecrets exposing (Msgs, view)

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
import Pages exposing (Page(..))
import RemoteData exposing (RemoteData(..), WebData)
import Util exposing (largeLoader)
import Vela
    exposing
        ( Secret
        , Secrets
        )


type alias AddSecret msg =
    msg


{-| Msgs : record for routing msg updates to Main.elm
-}
type alias Msgs msg =
    { addSecret : AddSecret msg
    }


{-| view : takes model and renders page for managing repo secrets
-}
view : WebData Secrets -> Html msg
view secrets =
    case secrets of
        Success s ->
            if List.length s > 0 then
                div [] [ addSecret, viewSecrets s ]

            else
                div [] [ text "no secrets found for this repository" ]

        _ ->
            div [] [ largeLoader ]


addSecret : Html msg
addSecret =
    div [ class "add-secret" ]
        [ div [ class "label" ] [ text "Add Secret" ]
        , div [] [ Html.input [ class "secret-name", Html.Attributes.placeholder "Secret Name" ] [] ]
        , div [] [ Html.textarea [ class "secret-value", Html.Attributes.placeholder "Secret Value" ] [] ]
        , div [] [ Html.button [ class "button", class "-outline" ] [ text "Add" ] ]
        ]


viewSecrets : Secrets -> Html msg
viewSecrets secrets =
    div [ class "table" ] <| secretsTable secrets


{-| secretsTable : renders secrets table
-}
secretsTable : Secrets -> List (Html msg)
secretsTable secrets =
    headers :: rows secrets


{-| headers : renders secrets table headers
-}
headers : Html msg
headers =
    div [ class "headers" ]
        [ div [ class "first-cell", class "table-label" ] [ text "Secrets" ]
        , div [ class "header" ] [ text "name" ]
        , div [ class "header" ] [ text "events" ]
        , div [ class "header" ] [ text "images" ]
        ]


{-| rows : renders secrets table rows
-}
rows : Secrets -> List (Html msg)
rows secrets =
    List.map (\secret -> row secret) secrets


{-| row : renders hooks table row wrapped in details element
-}
row : Secret -> Html msg
row secret =
    details [ class "details", class "-no-pad", Util.testAttribute "secret" ]
        [ summary [ class "summary" ]
            [ preview secret ]
        , info secret
        ]


{-| preview : renders the hook preview displayed as the clickable row
-}
preview : Secret -> Html msg
preview secret =
    div [ class "row", class "preview" ]
        [ firstCell
        , cell secret.name <| class "host"
        , arrayCell secret.events "no events"
        , arrayCell secret.images "no images"
        ]


arrayCell : List String -> String -> Html msg
arrayCell images default =
    div [ class "cell" ] <|
        List.intersperse (text ",") <|
            if List.length images > 0 then
                List.map (\image -> code [ class "text", class "-m-l" ] [ text image ]) images

            else
                [ code [ class "text" ] [ text default ] ]


{-| cell : takes text and maybe attributes and renders cell data for hooks table row
-}
cell : String -> Html.Attribute msg -> Html msg
cell txt cls =
    div [ class "cell", cls ]
        [ span [] [ text txt ] ]


{-| firstCell : renders the expansion chevron icon
-}
firstCell : Html msg
firstCell =
    div [ class "first-cell" ]
        [ FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
        ]


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
