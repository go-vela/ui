module Pages.Build.Graph.Interop exposing (renderBuildGraph)

import Interop
import Pages.Build.Graph.DOT exposing (renderDOT)
import Pages.Build.Model as BuildModel
import RemoteData exposing (RemoteData(..))
import Routes exposing (Route(..))
import Vela exposing (encodeBuildGraphRenderData)


{-| renderBuildGraph : takes partial build model and render options, and returns a cmd for dispatching a graphviz+d3 render command
-}
renderBuildGraph : BuildModel.PartialModel a -> Bool -> Cmd msg
renderBuildGraph model centerOnDraw =
    let
        rm =
            model.repo

        bm =
            rm.build

        gm =
            rm.build.graph
    in
    case gm.graph of
        Success g ->
            Interop.renderBuildGraph <|
                encodeBuildGraphRenderData
                    { dot = renderDOT model g
                    , buildID = RemoteData.unwrap -1 .id bm.build
                    , filter = gm.filter
                    , showServices = gm.showServices
                    , showSteps = gm.showSteps
                    , focusedNode = gm.focusedNode
                    , centerOnDraw = centerOnDraw
                    }

        _ ->
            Cmd.none
