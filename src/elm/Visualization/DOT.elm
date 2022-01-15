module Visualization.DOT exposing
    ( Attribute(..)
    , Rankdir(..)
    , Styles
    , escapeAttributes
    , escapeCharacters
    , outputWithStylesAndAttributes
    )

import Dict exposing (Dict)
import Graph exposing (Graph)
import Json.Encode


type alias Styles =
    { rankdir : Rankdir
    , graph : String
    , node : String
    , edge : String
    }


type Rankdir
    = TB
    | LR
    | BT
    | RL


type Attribute
    = DefaultJSONLabelEscape String
    | HtmlLabelEscape String


outputWithStylesAndAttributes :
    Styles
    -> (n -> Dict String Attribute)
    -> (e -> Dict String Attribute)
    -> Graph n e
    -> String
outputWithStylesAndAttributes styles nodeAttrs edgeAttrs graph =
    let
        encode : Attribute -> String
        encode attr =
            case attr of
                DefaultJSONLabelEscape s ->
                    Json.Encode.string s
                        |> Json.Encode.encode 0

                HtmlLabelEscape h ->
                    "<" ++ h ++ ">"

        attrAssocs : Dict String Attribute -> String
        attrAssocs =
            Dict.toList
                >> List.map (\( k, v ) -> k ++ "=" ++ encode v)
                >> String.join ", "

        makeAttrs : Dict String Attribute -> String
        makeAttrs d =
            if Dict.isEmpty d then
                ""

            else
                " [" ++ attrAssocs d ++ "]"

        edges =
            let
                compareEdge a b =
                    case compare a.from b.from of
                        LT ->
                            LT

                        GT ->
                            GT

                        EQ ->
                            compare a.to b.to
            in
            Graph.edges graph
                |> List.sortWith compareEdge

        nodes =
            Graph.nodes graph

        edgesString =
            List.map edge edges
                |> String.join "\n"

        edge e =
            "  "
                ++ String.fromInt e.from
                ++ " -> "
                ++ String.fromInt e.to
                ++ makeAttrs (edgeAttrs e.label)

        nodesString =
            List.map node nodes
                |> String.join "\n"

        node n =
            "  "
                ++ String.fromInt n.id
                ++ makeAttrs (nodeAttrs n.label)

        rankDirToString r =
            case r of
                TB ->
                    "TB"

                LR ->
                    "LR"

                BT ->
                    "BT"

                RL ->
                    "RL"
    in
    String.join "\n"
        [ "digraph G {"
        , "  rankdir=" ++ rankDirToString styles.rankdir
        , "  graph [" ++ styles.graph ++ "]"
        , "  node [" ++ styles.node ++ "]"
        , "  edge [" ++ styles.edge ++ "]"
        , ""
        , edgesString
        , ""
        , nodesString
        , "}"
        ]



-- HELPERS


{-| escapeCharacters : takes string and escapes special characters to prepare for use in a DOT string
-}
escapeCharacters : String -> String
escapeCharacters s =
    s
        |> String.replace "&" "&amp;"
        |> String.replace "<" "&lt;"
        |> String.replace ">" "&gt;"
        |> String.replace "\"" "&quot;"
        |> String.replace "'" "&#039;"


{-| escapeAttributes : takes list of string attributes and escapes special characters for keys and values to prepare for use in a DOT string
-}
escapeAttributes : List ( String, String ) -> String
escapeAttributes attrs =
    List.map
        (\( k, v ) ->
            escapeCharacters k ++ "=\"" ++ escapeCharacters v ++ "\""
        )
        attrs
        |> String.join " "
