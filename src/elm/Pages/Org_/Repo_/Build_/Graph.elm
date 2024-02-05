{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Graph exposing (..)

import Auth
import Browser.Events
import Components.Loading
import Components.Svgs
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Graph exposing (Edge, Node)
import Html exposing (button, div, li, text, ul)
import Html.Attributes exposing (checked, class, for, id, placeholder, title, type_, value)
import Html.Events exposing (onCheck, onClick, onInput)
import Http
import Http.Detailed
import Interop
import Layouts
import Page exposing (Page)
import Pages.Account.Login exposing (Msg(..))
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg
import Svg.Attributes
import Time
import Utils.Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)
import Visualization.DOT as DOT


page : Auth.User -> Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String, buildNumber : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Build
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org_Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "#" ++ route.params.buildNumber, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        , toBuildPath =
            \buildNumber ->
                Route.Path.Org_Repo_Build_Graph
                    { org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = buildNumber
                    }
        }



-- INIT


type alias Model =
    { build : WebData Vela.Build
    , graph : WebData Vela.BuildGraph
    , rankDir : DOT.Rankdir
    , filter : String
    , focusedNode : Int
    , showServices : Bool
    , showSteps : Bool
    }


init : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { build = RemoteData.Loading
      , graph = RemoteData.Loading
      , rankDir = DOT.LR
      , filter = ""
      , focusedNode = -1
      , showServices = True
      , showSteps = True
      }
    , Effect.batch
        [ Effect.getBuildGraph
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetBuildGraphResponse { freshDraw = True }
            , org = route.params.org
            , repo = route.params.repo
            , buildNumber = route.params.buildNumber
            }
        , clearBuildGraph |> Effect.sendCmd
        ]
    )



-- UPDATE


type Msg
    = NoOp
      -- BROWSER
    | VisibilityChanged { visibility : Browser.Events.Visibility }
      -- GRAPH
    | RenderBuildGraph { freshDraw : Bool }
    | GetBuildGraphResponse { freshDraw : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.BuildGraph ))
    | Refresh { freshDraw : Bool, setToLoading : Bool, clear : Bool }
    | Rotate
    | ShowHideServices Bool
    | ShowHideSteps Bool
    | UpdateFilter String
    | OnBuildGraphInteraction Vela.BuildGraphInteraction
      -- REFRESH
    | Tick { interval : Interval.Interval, time : Time.Posix }


update : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        -- BROWSER
        VisibilityChanged options ->
            ( model
            , if options.visibility == Browser.Events.Visible then
                Effect.sendMsg <| RenderBuildGraph { freshDraw = False }

              else
                Effect.none
            )

        -- GRAPH
        RenderBuildGraph options ->
            ( model
            , Effect.sendCmd <|
                renderBuildGraph shared model options
            )

        GetBuildGraphResponse options response ->
            case response of
                Ok ( _, graph ) ->
                    ( { model
                        | graph =
                            RemoteData.succeed graph
                      }
                    , Effect.sendMsg <| RenderBuildGraph { freshDraw = options.freshDraw }
                    )

                Err error ->
                    ( { model | graph = Utils.Errors.toFailure error }
                    , Effect.batch
                        [ Effect.handleHttpError { httpError = error }
                        , clearBuildGraph |> Effect.sendCmd
                        ]
                    )

        Refresh options ->
            ( { model
                | graph =
                    if options.setToLoading then
                        RemoteData.Loading

                    else
                        model.graph
              }
            , Effect.batch
                [ Effect.getBuildGraph
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetBuildGraphResponse { freshDraw = options.freshDraw }
                    , org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = route.params.buildNumber
                    }
                , if options.clear then
                    Effect.sendCmd clearBuildGraph

                  else
                    Effect.none
                ]
            )

        Rotate ->
            ( { model
                | rankDir =
                    case model.rankDir of
                        DOT.TB ->
                            DOT.LR

                        _ ->
                            DOT.TB
              }
            , Effect.sendMsg <| RenderBuildGraph { freshDraw = False }
            )

        ShowHideServices val ->
            ( { model
                | showServices =
                    val
              }
            , Effect.sendMsg <| RenderBuildGraph { freshDraw = False }
            )

        ShowHideSteps val ->
            ( { model
                | showSteps =
                    val
              }
            , Effect.sendMsg <| RenderBuildGraph { freshDraw = False }
            )

        UpdateFilter val ->
            ( { model
                | filter =
                    val
              }
            , Effect.sendMsg <| RenderBuildGraph { freshDraw = False }
            )

        OnBuildGraphInteraction interaction ->
            let
                ( ugm_, cmd ) =
                    case interaction.eventType of
                        "href" ->
                            ( model
                            , interaction.href
                                |> String.replace hrefHandle ""
                                |> Route.Path.fromString
                                |> Maybe.withDefault
                                    (Route.Path.Org_Repo_Build_Graph
                                        { org = route.params.org
                                        , repo = route.params.repo
                                        , buildNumber = route.params.buildNumber
                                        }
                                    )
                                |> Effect.pushPath
                            )

                        "backdrop_click" ->
                            ( { model | focusedNode = -1 }
                            , Effect.sendMsg <| RenderBuildGraph { freshDraw = False }
                            )

                        "node_click" ->
                            ( { model | focusedNode = Maybe.withDefault -1 <| String.toInt interaction.nodeID }
                            , Effect.sendMsg <| RenderBuildGraph { freshDraw = False }
                            )

                        _ ->
                            ( model, Effect.none )
            in
            ( ugm_
            , cmd
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.sendMsg <| Refresh { freshDraw = False, setToLoading = False, clear = False }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Interop.onGraphInteraction
            (Vela.decodeOnGraphInteraction OnBuildGraphInteraction NoOp)

        -- on visiblity changed, same as shared
        , Browser.Events.onVisibilityChange
            (\visibility -> VisibilityChanged { visibility = visibility })
        , Interval.tickEveryOneSecond Tick
        ]



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Model -> View Msg
view shared route model =
    { title = "Graph"
    , body =
        [ div [ class "elm-build-graph-container" ]
            [ div [ class "elm-build-graph-actions" ]
                [ ul []
                    [ li []
                        [ button
                            [ class "button"
                            , class "-icon"
                            , id "action-center"
                            , title "Recenter visualization"
                            ]
                            [ FeatherIcons.minimize
                                |> FeatherIcons.withSize 20
                                |> FeatherIcons.withClass "elm-build-graph-action-button"
                                |> FeatherIcons.toHtml []
                            ]
                        ]
                    , li []
                        [ button
                            [ class "button"
                            , class "-icon"
                            , class "build-graph-action-refresh"
                            , Html.Attributes.title "Refresh visualization"
                            , onClick <| Refresh { freshDraw = True, setToLoading = True, clear = True }
                            ]
                            [ FeatherIcons.refreshCw
                                |> FeatherIcons.withSize 20
                                |> FeatherIcons.withClass "elm-build-graph-action-button"
                                |> FeatherIcons.toHtml []
                            ]
                        ]
                    , li []
                        [ button
                            [ class "button"
                            , class "-icon"
                            , class "build-graph-action-rotate"
                            , class <|
                                case model.rankDir of
                                    DOT.TB ->
                                        "-vertical"

                                    _ ->
                                        ""
                            , title "Rotate visualization"
                            , onClick <| Rotate
                            ]
                            [ FeatherIcons.share2
                                |> FeatherIcons.withSize 20
                                |> FeatherIcons.withClass "elm-build-graph-action-button"
                                |> FeatherIcons.toHtml []
                            ]
                        ]
                    ]
                , div [ class "elm-build-graph-action-toggles" ]
                    [ div [ class "form-control" ]
                        [ div []
                            [ Html.input
                                [ type_ "checkbox"
                                , checked model.showServices
                                , onCheck ShowHideServices
                                , id "checkbox-services-toggle"
                                , Util.testAttribute "build-graph-action-toggle-services"
                                ]
                                []
                            , Html.label
                                [ class "form-label"
                                , for "checkbox-services-toggle"
                                ]
                                [ text "services"
                                ]
                            ]
                        ]
                    , div [ class "form-control" ]
                        [ div []
                            [ Html.input
                                [ type_ "checkbox"
                                , checked model.showSteps
                                , onCheck ShowHideSteps
                                , id "checkbox-steps-toggle"
                                , Util.testAttribute "build-graph-action-toggle-steps"
                                ]
                                []
                            , Html.label
                                [ class "form-label"
                                , for "checkbox-steps-toggle"
                                ]
                                [ text "steps"
                                ]
                            ]
                        ]
                    , div
                        [ class "form-control"
                        , class "elm-build-graph-search-filter"
                        ]
                        [ div [ class "elm-build-graph-search-filter-input" ]
                            [ Html.input
                                [ type_ "input"
                                , placeholder "type to highlight nodes..."
                                , onInput UpdateFilter
                                , id "build-graph-action-filter"
                                , Util.testAttribute "build-graph-action-filter"
                                , value model.filter
                                ]
                                []
                            , Html.label
                                [ class "elm-build-graph-search-filter-form-label"
                                , for "build-graph-action-filter"
                                ]
                                [ FeatherIcons.search
                                    |> FeatherIcons.withSize 20
                                    |> FeatherIcons.withClass "elm-build-graph-action-button"
                                    |> FeatherIcons.toHtml []
                                ]
                            ]
                        , button
                            [ class "button"
                            , class "-icon"
                            , Util.testAttribute "build-graph-action-filter-clear"
                            , onClick (UpdateFilter "")
                            ]
                            [ FeatherIcons.x
                                |> FeatherIcons.withSize 20
                                |> FeatherIcons.withClass "elm-build-graph-action-button"
                                |> FeatherIcons.toHtml []
                            ]
                        ]
                    ]
                ]
            , div [ class "elm-build-graph-window" ]
                [ ul [ class "elm-build-graph-legend" ]
                    [ li []
                        [ Components.Svgs.buildVizLegendNode
                            [ Svg.Attributes.class "-pending"
                            ]
                        , text "pending"
                        ]
                    , li [ class "-running-hover" ]
                        [ Components.Svgs.buildVizLegendNode
                            [ Svg.Attributes.class "-running"
                            ]
                        , text "running"
                        ]
                    , li []
                        [ Components.Svgs.buildVizLegendNode
                            [ Svg.Attributes.class "-success"
                            ]
                        , text "success"
                        ]
                    , li []
                        [ Components.Svgs.buildVizLegendNode
                            [ Svg.Attributes.class "-failure"
                            ]
                        , text "failed"
                        ]
                    , li []
                        [ Components.Svgs.buildVizLegendNode
                            [ Svg.Attributes.class "-canceled"
                            ]
                        , text "canceled"
                        ]
                    , li []
                        [ Components.Svgs.buildVizLegendNode
                            [ Svg.Attributes.class "-killed"
                            ]
                        , text "skipped"
                        ]
                    , li []
                        [ Components.Svgs.buildVizLegendNode
                            [ Svg.Attributes.class "-selected"
                            ]
                        , text "selected"
                        ]
                    , li []
                        [ Components.Svgs.buildVizLegendEdge
                            [ Svg.Attributes.class "-pending"
                            ]
                        , text "pending"
                        ]
                    , li []
                        [ Components.Svgs.buildVizLegendEdge
                            [ Svg.Attributes.class "-finished"
                            ]
                        , text "complete"
                        ]
                    ]
                , case model.graph of
                    RemoteData.Success _ ->
                        -- dont render anything when the build graph draw command has been dispatched
                        text ""

                    RemoteData.Failure _ ->
                        div [ class "elm-build-graph-error" ]
                            [ text "Unable to load build graph, please refresh or try again later!"
                            ]

                    RemoteData.Loading ->
                        Components.Loading.viewSmallLoader

                    RemoteData.NotAsked ->
                        Components.Loading.viewSmallLoader
                , Svg.svg
                    [ Svg.Attributes.class "elm-build-graph-root"
                    ]
                    []
                ]
            ]
        ]
    }


{-| renderBuildGraph : takes partial build model and render options, and returns a cmd for dispatching a graphviz+d3 render command
-}
renderBuildGraph : Shared.Model -> Model -> { freshDraw : Bool } -> Cmd msg
renderBuildGraph shared model props =
    case model.graph of
        RemoteData.Success g ->
            Interop.renderBuildGraph <|
                Vela.encodeBuildGraphRenderData
                    { dot = renderDOT shared model g
                    , buildID = g.buildID
                    , filter = model.filter
                    , showServices = model.showServices
                    , showSteps = model.showSteps
                    , focusedNode = model.focusedNode
                    , freshDraw = props.freshDraw
                    }

        _ ->
            Cmd.none


{-| clearBuildGraph : returns a cmd for dispatching a graphviz+d3 render command to clear the graph
-}
clearBuildGraph : Cmd msg
clearBuildGraph =
    Interop.renderBuildGraph <|
        Vela.encodeBuildGraphRenderData
            { dot = ""
            , buildID = -1
            , filter = ""
            , showServices = True
            , showSteps = True
            , focusedNode = -1
            , freshDraw = True
            }


{-| renderDOT : takes model and build graph, and returns a string representation of a DOT graph using the extended Graph DOT package
<https://graphviz.org/doc/info/lang.html>
<https://package.elm-lang.org/packages/elm-community/graph/latest/Graph.DOT>
-}
renderDOT : Shared.Model -> Model -> Vela.BuildGraph -> String
renderDOT shared model graph =
    let
        isNodeFocused : String -> Vela.BuildGraphNode -> Bool
        isNodeFocused filter n =
            n.id
                == model.focusedNode
                || (String.length filter > 2)
                && (String.contains filter n.name
                        || List.any (\s -> String.contains filter s.name) n.steps
                   )

        isEdgeFocused : Int -> Vela.BuildGraphEdge -> Bool
        isEdgeFocused focusedNode e =
            focusedNode == e.destination || focusedNode == e.source

        -- convert BuildGraphNode to Graph.Node
        inNodes =
            graph.nodes
                |> Dict.toList
                |> List.map
                    (\( _, n ) ->
                        Node n.id
                            (Vela.BuildGraphNode n.cluster n.id n.name n.status n.startedAt n.finishedAt n.steps (isNodeFocused model.filter n))
                    )

        -- convert BuildGraphEdge to Graph.Edge
        inEdges =
            graph.edges
                |> List.map
                    (\e -> Edge e.source e.destination (Vela.BuildGraphEdge e.cluster e.source e.destination e.status (isEdgeFocused model.focusedNode e)))

        -- construct a Graph to extract nodes and edges
        ( nodes, edges ) =
            Graph.fromNodesAndEdges inNodes inEdges
                |> (\g -> ( Graph.nodes g, Graph.edges g ))

        -- group nodes based on cluster
        builtInNodes =
            nodes
                |> List.filter (\n -> n.label.cluster == builtInClusterID)

        pipelineNodes =
            nodes
                |> List.filter (\n -> n.label.cluster == pipelineClusterID)

        serviceNodes =
            nodes
                |> List.filter (\n -> n.label.cluster == serviceClusterID)

        -- group edges based on cluster
        builtInEdges =
            edges
                |> List.filter (\e -> e.label.cluster == builtInClusterID)

        pipelineEdges =
            edges
                |> List.filter (\e -> e.label.cluster == pipelineClusterID)

        serviceEdges =
            edges
                |> List.filter (\e -> e.label.cluster == serviceClusterID)

        -- convert nodes and edges to DOT string format
        builtInNodesString =
            List.map (nodeToString shared model graph) builtInNodes
                |> String.join "\n"

        pipelineNodesString =
            List.map (nodeToString shared model graph) pipelineNodes
                |> String.join "\n"

        serviceNodesString =
            List.map (nodeToString shared model graph) serviceNodes
                |> String.join "\n"

        builtInEdgesString =
            List.map edgeToString builtInEdges
                |> String.join "\n"

        pipelineEdgesString =
            List.map edgeToString pipelineEdges
                |> String.join "\n"

        serviceEdgesString =
            List.map edgeToString serviceEdges
                |> String.join "\n"

        -- construct DOT subgraphs using nodes and edges
        pipelineSubgraph =
            DOT.clusterSubgraph pipelineClusterID pipelineSubgraphStyles pipelineNodesString pipelineEdgesString

        builtInSubgraph =
            DOT.clusterSubgraph builtInClusterID builtInSubgraphStyles builtInNodesString builtInEdgesString

        serviceSubgraph =
            if model.showServices then
                DOT.clusterSubgraph serviceClusterID serviceSubgraphStyles serviceNodesString serviceEdgesString

            else
                ""

        -- reverse the subgraphs for top-bottom rankdir to consistently group services and built-ins
        rotation =
            case model.rankDir of
                DOT.TB ->
                    List.reverse

                _ ->
                    identity

        subgraphs =
            [ -- pipeline (stages, steps) subgraph and cluster
              pipelineSubgraph
            , ""

            -- built-in (init, clone) subgraph and cluster
            , builtInSubgraph
            , ""

            -- services subgraph and cluster
            , serviceSubgraph
            ]
    in
    DOT.digraph (baseGraphStyles model.rankDir)
        (rotation subgraphs)


{-| nodeLabel : takes model, graph info, a node, and returns a string representation of the "label" applied to a node element.
a "label" is actually a disguised graphviz table <https://graphviz.org/doc/info/lang.html> that is used to
render a list of stage-steps as graph content that is recognized by the layout
-}
nodeLabel : Shared.Model -> Model -> Vela.BuildGraph -> Vela.BuildGraphNode -> Bool -> String
nodeLabel shared model graph node showSteps =
    let
        label =
            node.name

        steps =
            List.sortBy .id node.steps

        table content =
            "<table "
                ++ DOT.escapeAttributes nodeLabelTableAttributes
                ++ ">"
                ++ String.concat content
                ++ "</table>"

        runtime =
            Util.formatRunTime shared.time node.startedAt node.finishedAt

        header =
            "<tr>"
                ++ "<td "
                ++ DOT.escapeAttributes
                    [ ( "align", DOT.DefaultEscape "left" )
                    ]
                ++ " >"
                ++ ("<font>"
                        ++ "<u>"
                        ++ label
                        ++ "</u>"
                        ++ "</font>"
                        ++ (if node.cluster /= serviceClusterID then
                                "  <font>("
                                    ++ (String.fromInt <| List.length steps)
                                    ++ ")</font>"

                            else
                                ""
                           )
                   )
                ++ "</td>"
                ++ "<td><font>"
                ++ runtime
                ++ "</font></td>"
                ++ "</tr>"

        link step =
            Route.toString <|
                { path =
                    Route.Path.Org_Repo_Build_
                        { org = graph.org
                        , repo = graph.repo
                        , buildNumber = String.fromInt graph.buildNumber
                        }
                , hash = Just <| hrefHandle ++ String.fromInt step.number
                , query = Dict.empty
                }

        -- table row and cell styling
        rowAttributes _ =
            [-- row attributes go here
            ]

        cellAttributes step =
            [ ( "border", DOT.DefaultEscape "0" )
            , ( "cellborder", DOT.DefaultEscape "0" )
            , ( "cellspacing", DOT.DefaultEscape "0" )
            , ( "margin", DOT.DefaultEscape "0" )
            , ( "align", DOT.DefaultEscape "left" )
            , ( "href", DOT.DefaultEscape <| link step )
            , ( "id", DOT.DefaultEscape "node-cell" )
            , ( "title", DOT.DefaultEscape ("#status-" ++ Vela.statusToString step.status) )
            , ( "tooltip"
              , DOT.DefaultEscape
                    (String.join ","
                        [ String.fromInt step.id
                        , step.name
                        , Vela.statusToString step.status
                        ]
                    )
              )
            ]

        row step =
            "<tr "
                ++ DOT.escapeAttributes
                    (rowAttributes step)
                ++ ">"
                ++ "<td "
                ++ DOT.escapeAttributes
                    (cellAttributes step)
                ++ " "
                ++ ">"
                -- required icon spacing
                ++ "     "
                ++ "<font>"
                ++ step.name
                ++ "</font>"
                ++ "<br align='left'/>"
                ++ "</td>"
                ++ "</tr>"

        rows =
            if showSteps then
                List.map row steps

            else
                []
    in
    table <| header :: rows


{-| nodeLabel : takes model and a node, and returns the DOT string representation
-}
nodeToString : Shared.Model -> Model -> Vela.BuildGraph -> Node Vela.BuildGraphNode -> String
nodeToString shared model graph node =
    "  "
        ++ String.fromInt node.id
        ++ DOT.makeAttributes (nodeAttributes shared model graph node.label)


{-| edgeToString : takes model and a node, and returns the DOT string representation
-}
edgeToString : Edge Vela.BuildGraphEdge -> String
edgeToString edge =
    "  "
        ++ String.fromInt edge.from
        ++ " -> "
        ++ String.fromInt edge.to
        ++ DOT.makeAttributes (edgeAttributes edge.label)



-- STYLES


{-| baseGraphStyles : returns the base styles applied to the root graph.
-}
baseGraphStyles : DOT.Rankdir -> DOT.Styles
baseGraphStyles rankdir =
    { rankdir = rankdir
    , graph =
        DOT.escapeAttributes
            [ ( "bgcolor", DOT.DefaultEscape "transparent" )
            , ( "splines", DOT.DefaultEscape "ortho" )
            ]
    , node =
        DOT.escapeAttributes
            [ ( "color", DOT.DefaultEscape "#151515" )
            , ( "style", DOT.DefaultEscape "filled" )
            , ( "fontname", DOT.DefaultEscape "Arial" )
            ]
    , edge =
        DOT.escapeAttributes
            [ ( "color", DOT.DefaultEscape "azure2" )
            , ( "penwidth", DOT.DefaultEscape "1" )
            , ( "arrowhead", DOT.DefaultEscape "dot" )
            , ( "arrowsize", DOT.DefaultEscape "0.5" )
            , ( "minlen", DOT.DefaultEscape "1" )
            ]
    }


{-| builtInSubgraphStyles : returns the styles applied to the built-in-steps subgraph.
-}
builtInSubgraphStyles : DOT.Styles
builtInSubgraphStyles =
    { rankdir = DOT.LR -- unused with subgraph but required by model
    , graph =
        DOT.escapeAttributes
            [ ( "bgcolor", DOT.DefaultEscape "transparent" )
            , ( "peripheries", DOT.DefaultEscape "0" )
            ]
    , node =
        DOT.escapeAttributes
            [ ( "color", DOT.DefaultEscape "#151515" )
            , ( "style", DOT.DefaultEscape "filled" )
            , ( "fontname", DOT.DefaultEscape "Arial" )
            ]
    , edge =
        DOT.escapeAttributes
            [ ( "minlen", DOT.DefaultEscape "1" )
            ]
    }


{-| pipelineSubgraphStyles : returns the styles applied to the pipeline-steps subgraph.
-}
pipelineSubgraphStyles : DOT.Styles
pipelineSubgraphStyles =
    { rankdir = DOT.LR -- unused with subgraph but required by model
    , graph =
        DOT.escapeAttributes
            [ ( "bgcolor", DOT.DefaultEscape "transparent" )
            , ( "peripheries", DOT.DefaultEscape "0" )
            ]
    , node =
        DOT.escapeAttributes
            [ ( "color", DOT.DefaultEscape "#151515" )
            , ( "style", DOT.DefaultEscape "filled" )
            , ( "fontname", DOT.DefaultEscape "Arial" )
            ]
    , edge =
        DOT.escapeAttributes
            [ ( "color", DOT.DefaultEscape "azure2" )
            , ( "penwidth", DOT.DefaultEscape "2" )
            , ( "arrowhead", DOT.DefaultEscape "dot" )
            , ( "arrowsize", DOT.DefaultEscape "0.5" )
            , ( "minlen", DOT.DefaultEscape "2" )
            ]
    }


{-| serviceSubgraphStyles : returns the styles applied to the services subgraph.
-}
serviceSubgraphStyles : DOT.Styles
serviceSubgraphStyles =
    { rankdir = DOT.LR -- unused with subgraph but required by model
    , graph =
        DOT.escapeAttributes
            [ ( "bgcolor", DOT.DefaultEscape "transparent" )
            , ( "peripheries", DOT.DefaultEscape "0" )
            ]
    , node =
        DOT.escapeAttributes
            [ ( "color", DOT.DefaultEscape "#151515" )
            , ( "style", DOT.DefaultEscape "filled" )
            , ( "fontname", DOT.DefaultEscape "Arial" )
            ]
    , edge =
        DOT.escapeAttributes
            [ ( "color", DOT.DefaultEscape "azure2" )
            , ( "penwidth", DOT.DefaultEscape "0" )
            , ( "arrowhead", DOT.DefaultEscape "dot" )
            , ( "arrowsize", DOT.DefaultEscape "0" )
            , ( "minlen", DOT.DefaultEscape "1" )
            , ( "style", DOT.DefaultEscape "invis" )
            ]
    }


{-| nodeLabelTableAttributes : returns the base styles applied to all node label-tables
-}
nodeLabelTableAttributes : List ( String, DOT.AttributeValue )
nodeLabelTableAttributes =
    [ ( "border", DOT.DefaultEscape "0" )
    , ( "cellborder", DOT.DefaultEscape "0" )
    , ( "cellspacing", DOT.DefaultEscape "5" )
    , ( "margin", DOT.DefaultEscape "0" )
    ]


{-| nodeAttributes : returns the node-specific dynamic attributes
-}
nodeAttributes : Shared.Model -> Model -> Vela.BuildGraph -> Vela.BuildGraphNode -> Dict String DOT.Attribute
nodeAttributes shared model buildGraph node =
    let
        -- embed node information in the element id
        id =
            "#"
                ++ String.join ","
                    [ String.fromInt node.id
                    , node.name
                    , node.status
                    , Util.boolToString node.focused
                    ]

        class =
            String.join " "
                [ "elm-build-graph-node" -- generic styling
                , "elm-build-graph-node-" ++ String.fromInt node.id -- selector used for testing
                ]

        -- track step expansion using the model and OnGraphInteraction
        showSteps =
            model.showSteps
    in
    Dict.fromList <|
        -- node attributes
        [ ( "shape", DOT.DefaultJSONLabelEscape "rect" )
        , ( "style", DOT.DefaultJSONLabelEscape "filled" )
        , ( "border", DOT.DefaultJSONLabelEscape "white" )

        -- dynamic attributes
        , ( "id", DOT.DefaultJSONLabelEscape id )
        , ( "class", DOT.DefaultJSONLabelEscape class )
        , ( "href", DOT.DefaultJSONLabelEscape ("#" ++ node.name) )
        , ( "label", DOT.HtmlLabelEscape <| nodeLabel shared model buildGraph node showSteps )
        , ( "tooltip", DOT.DefaultJSONLabelEscape id )
        ]


{-| edgeAttributes : returns the edge-specific dynamic attributes
-}
edgeAttributes : Vela.BuildGraphEdge -> Dict String DOT.Attribute
edgeAttributes edge =
    let
        -- embed edge information in the element id to use during OnGraphInteraction callbacks
        id =
            "#"
                ++ String.join ","
                    [ String.fromInt edge.source
                    , String.fromInt edge.destination
                    , edge.status
                    , Util.boolToString edge.focused
                    ]

        class =
            String.join " "
                [ "elm-build-graph-edge" -- generic styling

                -- selector used for testing
                , "elm-build-graph-edge-"
                    ++ String.fromInt edge.source
                    ++ "-"
                    ++ String.fromInt edge.destination
                ]
    in
    Dict.fromList <|
        [ ( "id", DOT.DefaultJSONLabelEscape id )
        , ( "class", DOT.DefaultJSONLabelEscape class )
        , ( "style", DOT.DefaultJSONLabelEscape "filled" )
        ]


{-| builtInClusterID : constant for organizing the layout of build graph nodes
-}
builtInClusterID : Int
builtInClusterID =
    2


{-| pipelineClusterID : constant for organizing the layout of build graph nodes
-}
pipelineClusterID : Int
pipelineClusterID =
    1


{-| serviceClusterID : constant for organizing the layout of build graph nodes
-}
serviceClusterID : Int
serviceClusterID =
    0


{-| hrefHandle : constant for handling hrefs in the graph
-}
hrefHandle : String
hrefHandle =
    "href:"
