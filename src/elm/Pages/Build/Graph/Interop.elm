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
    -- rendering the full graph requires repo, build and graph
    case ( model.repo.repo, model.repo.build.build, model.repo.build.graph.graph ) of
        ( Success r, Success b, Success g ) ->
            Interop.renderBuildGraph <|
                encodeBuildGraphRenderData
                    { dot = renderDOT model r b g
                    , buildID = b.id
                    , filter = model.repo.build.graph.filter
                    , showServices = model.repo.build.graph.showServices
                    , showSteps = model.repo.build.graph.showSteps
                    , focusedNode = model.repo.build.graph.focusedNode
                    , centerOnDraw = centerOnDraw
                    }

        _ ->
            Cmd.none
