module Visualization.DOT exposing
    ( Attribute(..)
    , AttributeValue(..)
    , Rankdir(..)
    , Styles
    , attrAssocs
    , attrToString
    , clusterSubgraph
    , digraph
    , escapeAttributes
    , escapeCharacters
    , makeAttrs
    )

import Dict exposing (Dict)
import Json.Encode



-- TYPES


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


type AttributeValue
    = DefaultEscape String
    | BooleanEscape String



-- DOT HELPERS


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
escapeAttributes attrs =
    List.map
        (\( k, attrV ) ->
            case attrV of
                DefaultEscape v ->
                    escapeCharacters k ++ "=\"" ++ escapeCharacters v ++ "\""

                BooleanEscape v ->
                    escapeCharacters k ++ "=" ++ v ++ ""
        )
        attrs
        |> String.join " "


{-| attrToString : takes attribute and returns it as a string
-}
attrToString : Attribute -> String
attrToString attr =
    case attr of
        DefaultJSONLabelEscape s ->
            Json.Encode.string s
                |> Json.Encode.encode 0

        HtmlLabelEscape h ->
            "<" ++ h ++ ">"


{-| makeAttrs : takes dictionary of attributes and returns them as a string
-}
makeAttrs : Dict String Attribute -> String
makeAttrs d =
    if Dict.isEmpty d then
        ""

    else
        " [" ++ attrAssocs d ++ "]"


{-| attrAssocs : takes dictionary of attributes and returns them as a string
-}
attrAssocs : Dict String Attribute -> String
attrAssocs =
    Dict.toList
        >> List.map (\( k, v ) -> k ++ "=" ++ attrToString v)
        >> String.join ", "
