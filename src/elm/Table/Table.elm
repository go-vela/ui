{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Table.Table exposing (Row, view)

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
import Pages.Secrets.Types exposing (Msg(..), PartialModel)
import RemoteData exposing (RemoteData(..), WebData)
import Util exposing (largeLoader)
import Vela
    exposing
        ( Key
        , Org
        , Repo
        , Repository
        , Secret
        , SecretType
        , Secrets
        , Session
        , Team
        , UpdateSecretPayload
        , buildUpdateSecretPayload
        , defaultRepository
        , encodeUpdateSecret
        , nullSecret
        , secretTypeToString
        , toSecretType
        )


type alias Column data =
    { name : String
    , display : data -> Html Msg
    }


type alias Columns data =
    List (Column data)


type alias Row data =
    { data : data
    , display : data -> Html Msg
    }


type alias Rows data =
    List (Row data)


findColumn : Row data -> Columns data -> Maybe (Column data)
findColumn row columns =
    Nothing


demoColumns : Columns Secret
demoColumns =
    [ Column "name of repo" (\repo -> div [] [ text repo.name ]) ]


demoRows : Rows Secret
demoRows =
    [ Row (Secret 0 "org..." "repo..." "team..." "name..." Vela.Org [ "event..." ] [ "image..." ] True)
        renderSecret
    ]


renderSecret : Secret -> Html Msg
renderSecret secret =
    div [ class "row", class "preview" ]
        [ cell secret.name <| class "host"
        , cell (secretTypeToString secret.type_) <| class ""
        , arrayCell secret.events "no events"
        , arrayCell secret.images "all images"
        , cell (Util.boolToYesNo secret.allowCommand) <| class ""
        ]


{-| view : renders data table
-}
view : Columns data -> Rows data -> Html Msg
view columns rows =
    -- div [ class "secrets-table", class "table" ] <| table columns rows
    div [ class "secrets-table", class "table" ] <| table demoColumns demoRows


{-| table : renders table rows
-}
table : List (Column a) -> List (Row a) -> List (Html Msg)
table columns rows =
    [ div [ class "table-label" ] [ text "Secrets" ], headers columns ]
        ++ (if List.length rows > 0 then
                viewRows rows

            else
                [ div [ class "no-secrets" ] [ text "No secrets found for this repository" ] ]
           )


{-| headers : renders secrets table headers
-}
headers : List (Column a) -> Html Msg
headers columns =
    div [ class "headers" ]
        [ div [ class "header" ] [ text "name" ]
        , div [ class "header" ] [ text "type" ]
        , div [ class "header" ] [ text "events" ]
        , div [ class "header" ] [ text "images" ]
        , div [ class "header" ] [ text "allow commands" ]
        ]


{-| viewRows : renders data table rows
-}
viewRows : Rows a -> List (Html Msg)
viewRows rows =
    List.map viewRow rows


{-| viewRow : renders hooks table row wrapped in details element
-}
viewRow : Row a -> Html Msg
viewRow row =
    div [ class "details", class "-no-pad", Util.testAttribute "secret" ]
        [ div [ class "secrets-row" ]
            [ row.display row.data ]
        ]


secretPreview : Row a -> Html Msg
secretPreview row =
    div [] [ text "secret.name" ]


otherPreview : Row a -> Html Msg
otherPreview row =
    div [] [ text "other.other" ]


{-| preview : renders the hook preview displayed as the clickable row
-}
preview :
    { a | name : String, type_ : SecretType, events : List String, images : List String, allowCommand : Bool }
    -> Html Msg
preview secret =
    div [ class "row", class "preview" ]
        [ cell secret.name <| class "host"
        , cell (secretTypeToString secret.type_) <| class ""
        , arrayCell secret.events "no events"
        , arrayCell secret.images "all images"
        , cell (Util.boolToYesNo secret.allowCommand) <| class ""
        ]


{-| cell : takes text and maybe attributes and renders cell data for hooks table row
-}
cell : String -> Html.Attribute Msg -> Html Msg
cell txt cls =
    div [ class "cell", cls ]
        [ span [] [ text txt ] ]


{-| arrayCell : takes string array and renders cell
-}
arrayCell : List String -> String -> Html Msg
arrayCell images default =
    div [ class "cell" ] <|
        List.intersperse (text ",") <|
            if List.length images > 0 then
                List.map (\image -> code [ class "text", class "-m-l" ] [ text image ]) images

            else
                [ code [ class "text" ] [ text default ] ]
