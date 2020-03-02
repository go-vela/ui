{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.RepoSecrets exposing (Msgs, view)

import Html
    exposing
        ( Html
        , br
        , details
        , div
        , em
        , h2
        , p
        , section
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
    let
        secrets_ =
            case secrets of
                Success s ->
                    if List.length s > 0 then
                        viewSecrets s

                    else
                        div [] [ text "no secrets found for this repository" ]

                _ ->
                    div [] [ largeLoader ]
    in
    secrets_


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
        [ div [ class "header" ] [ text "name" ]
        , div [ class "header" ] [ text "type" ]
        , div [ class "header" ] [ text "events" ]
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
        [ summary [ class "summary", class "-no-pad" ]
            [ preview secret ]
        , info secret
        ]


{-| preview : renders the hook preview displayed as the clickable row
-}
preview : Secret -> Html msg
preview secret =
    div [ class "row", class "preview" ]
        [ cell secret.name <| class "host"
        , cell secret.name <| class "event"
        , cell secret.name <| class "branch"
        ]


{-| cell : takes text and maybe attributes and renders cell data for hooks table row
-}
cell : String -> Html.Attribute msg -> Html msg
cell txt cls =
    div [ class "cell", cls ]
        [ span [] [ text txt ] ]


{-| info : renders the table row details when clicking/expanding a row
-}
info : Secret -> Html msg
info secret =
    div [ class "loading" ] [ Util.smallLoaderWithText "loading secret..." ]


viewSecret : Secret -> Html msg
viewSecret secret =
    div [] [ text secret.name ]
