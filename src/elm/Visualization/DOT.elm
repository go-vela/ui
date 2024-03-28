{--
SPDX-License-Identifier: Apache-2.0
--}


module Visualization.DOT exposing
    ( Attribute(..)
    , AttributeValue(..)
    , Rankdir(..)
    , Styles
    , clusterSubgraph
    , digraph
    , escapeAttributes
    , makeAttributes
    )

import Dict exposing (Dict)
import Json.Encode



-- TYPES


{-| Styles : graph style options
-}
type alias Styles =
    { rankdir : Rankdir
    , graph : String
    , node : String
    , edge : String
    }


{-| Rankdir : direction of the graph render layout
-}
type Rankdir
    = TB
    | LR
    | BT
    | RL


{-| Attribute : used for escaping graph layout attribute keys
-}
type Attribute
    = DefaultJSONLabelEscape String
    | HtmlLabelEscape String


{-| AttributeValue : used for escaping graph layout attribute values
-}
type AttributeValue
    = DefaultEscape String
    | BooleanEscape String



-- DOT HELPERS


{-| digraph : takes styles and graph content and wraps it in a DOT directed graph layout to be
used with graphviz/DOT: <https://graphviz.org/doc/info/lang.html>
-}
digraph : Styles -> List String -> String
digraph styles content =
    String.join "\n" <|
        List.concat
            [ [ "digraph G {" -- start graph
              , "  compound=true" -- adds support for subgraph edges
              , "  rankdir=" ++ rankDirToString styles.rankdir
              , "  graph [" ++ styles.graph ++ "]"
              , "  node [" ++ styles.node ++ "]"
              , "  edge [" ++ styles.edge ++ "]"
              , ""
              ]
            , content
            , [ ""
              , "}" -- end graph
              , ""
              ]
            ]


{-| clusterSubgraph : takes cluster ID, styles, nodes and edges, and wraps it in a DOT directed subgraph layout to be
used with graphviz/DOT: <https://graphviz.org/doc/info/lang.html>
-}
clusterSubgraph : Int -> Styles -> String -> String -> String
clusterSubgraph cluster styles nodesString edgesString =
    String.join "\n"
        [ "subgraph cluster_" ++ String.fromInt cluster ++ " {" -- start subgraph
        , "  graph [" ++ styles.graph ++ "]"
        , "  node [" ++ styles.node ++ "]"
        , "  edge [" ++ styles.edge ++ "]"
        , ""
        , edgesString
        , ""
        , nodesString
        , ""
        , "}" -- end subgraph
        ]


{-| rankDirToString : takes Rankdir type and returns it as a string
-}
rankDirToString : Rankdir -> String
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
escapeAttributes : List ( String, AttributeValue ) -> String
escapeAttributes attributes =
    List.map
        (\( k, attributeValue ) ->
            case attributeValue of
                DefaultEscape v ->
                    escapeCharacters k ++ "=\"" ++ escapeCharacters v ++ "\""

                BooleanEscape v ->
                    escapeCharacters k ++ "=" ++ v ++ ""
        )
        attributes
        |> String.join " "


{-| attributeToString : takes attribute and returns it as a string
-}
attributeToString : Attribute -> String
attributeToString attribute =
    case attribute of
        DefaultJSONLabelEscape s ->
            Json.Encode.string s
                |> Json.Encode.encode 0

        HtmlLabelEscape h ->
            "<" ++ h ++ ">"


{-| makeAttributes : takes dictionary of attributes and returns them as a string
-}
makeAttributes : Dict String Attribute -> String
makeAttributes d =
    if Dict.isEmpty d then
        ""

    else
        " [" ++ attributeKeyValuePairs d ++ "]"


{-| attributeKeyValuePairs : helper for taking dictionary of attributes and returns them as a string
-}
attributeKeyValuePairs : Dict String Attribute -> String
attributeKeyValuePairs =
    Dict.toList
        >> List.map (\( k, v ) -> k ++ "=" ++ attributeToString v)
        >> String.join ", "
