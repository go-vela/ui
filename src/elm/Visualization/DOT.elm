module Visualization.DOT exposing
    ( Attribute(..)
    , AttributeValue(..)
    , Rankdir(..)
    , Styles
    , escapeAttributes
    , escapeCharacters
    , outputWithStylesAndAttributes
    )

import Dict exposing (Dict)
import Graph exposing (Edge, Graph, Node)
import Json.Encode
import Maybe.Extra


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


outputWithStylesAndAttributes :
    Styles
    -> Styles
    -> Styles
    -> (n -> Dict String Attribute)
    -> (e -> Dict String Attribute)
    -> Graph n e
    -> String
outputWithStylesAndAttributes baseGraphStyles pipelineSubgraphStyles builtInSubgraphStyles nodeAttrs edgeAttrs graph =
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

        nodes =
            Graph.nodes graph

        isBuiltInNode : Node nn -> Bool
        isBuiltInNode n_ =
            n_.id < 0

        pipelineNodes =
            nodes
                |> List.filter (\n -> not <| isBuiltInNode n)

        builtInNodes =
            nodes
                |> List.filter (\n -> isBuiltInNode n)

        nodeToString n =
            "  "
                ++ String.fromInt n.id
                ++ makeAttrs (nodeAttrs n.label)

        builtInNodesString =
            List.map nodeToString builtInNodes
                |> String.join "\n"

        pipelineNodesString =
            List.map nodeToString pipelineNodes
                |> String.join "\n"

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

        isBuiltInEdge : Edge ee -> Bool
        isBuiltInEdge e_ =
            e_.from < -1 || e_.to < -1

        pipelineEdges =
            edges
                |> List.filter (\e -> not <| isBuiltInEdge e)

        builtInEdges =
            edges
                |> List.filter (\e -> isBuiltInEdge e)

        edgeToString e =
            "  "
                ++ String.fromInt e.from
                ++ " -> "
                ++ String.fromInt e.to
                ++ makeAttrs (edgeAttrs e.label)

        builtInEdgesString =
            List.map edgeToString builtInEdges
                |> String.join "\n"

        pipelineEdgesString =
            List.map edgeToString pipelineEdges
                |> String.join "\n"

        -- biSource =
        --     String.fromInt <| Maybe.Extra.unwrap -3 (\b -> b.id) <| List.head <| List.reverse <| List.sortBy .id builtInNodes
        -- biDest =
        --     String.fromInt <| Maybe.Extra.unwrap 1 (\b -> b.id) <| List.head <| List.sortBy .id pipelineNodes
    in
    String.join "\n" <|
        [ "digraph G {" -- start graph
        , "  compound=true" -- adds support for subgraph edges
        , "  rankdir=" ++ rankDirToString baseGraphStyles.rankdir
        , "  graph [" ++ baseGraphStyles.graph ++ "]"
        , "  node [" ++ baseGraphStyles.node ++ "]"
        , "  edge [" ++ baseGraphStyles.edge ++ "]"
        , ""
        , "  subgraph cluster_1 {" -- start pipeline subgraph
        , "  graph [" ++ pipelineSubgraphStyles.graph ++ "]"
        , "  node [" ++ pipelineSubgraphStyles.node ++ "]"
        , "  edge [" ++ pipelineSubgraphStyles.edge ++ "]"
        , ""
        , pipelineEdgesString
        , ""
        , pipelineNodesString
        , ""
        , "}" -- end pipeline subgraph
        , ""
        , "  subgraph cluster_0 {" -- start built-ins subgraph
        , "  graph [" ++ builtInSubgraphStyles.graph ++ "]"
        , "  node [" ++ builtInSubgraphStyles.node ++ "]"
        , "  edge [" ++ builtInSubgraphStyles.edge ++ "]"
        , ""
        , builtInEdgesString
        , ""
        , builtInNodesString
        , ""
        , "}" -- end built-ins subgraph
        , ""
        , "}" -- end graph
        , ""
        ]



-- HELPERS


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
