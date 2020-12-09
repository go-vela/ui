{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.View exposing (viewPipeline)

import Ansi.Log
import Array
import DateFormat.Relative exposing (relativeTime)
import Dict
import Dict.Extra
import Errors exposing (Error, detailedErrorToString)
import FeatherIcons exposing (Icon)
import Focus exposing (ExpandTemplatesQuery, FocusLineNumber, Fragment, RefQuery, Resource, ResourceID, lineFocusStyles, lineRangeId, resourceAndLineToFocusId)
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , div
        , small
        , span
        , strong
        , table
        , td
        , text
        , tr
        )
import Html.Attributes exposing (attribute, class, href, title)
import Html.Events exposing (onClick)
import List.Extra
import Nav exposing (viewBuildNav)
import Pages exposing (Page(..))
import Pages.Build.Logs exposing (decodeAnsi)
import Pages.Build.View exposing (viewLine)
import Pages.Pipeline.Model exposing (Expand, Get, Msgs, PartialModel)
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import SvgBuilder exposing (buildStatusToIcon)
import Time exposing (Posix, Zone)
import Util
import Vela
    exposing
        ( Build
        , LogFocus
        , Org
        , Pipeline
        , PipelineConfig
        , Repo
        , Status
        , Step
        , Steps,Ref
        , Template
        , Templates
        )



-- VIEW


{-| viewPipeline : renders entire build based on current application time
-}
viewPipeline : PartialModel a -> Msgs msg -> Org -> Repo -> Maybe Ref -> Html msg
viewPipeline model msgs org repo ref =
    let
        rm =
            model.repo

        build =
            rm.build

        ( buildPreview, navTabs ) =
            case build.build of
                RemoteData.Success bld ->
                    ( Pages.Build.View.viewPreview model.time model.zone org repo bld, viewBuildNav model org repo bld model.page )

                RemoteData.Loading ->
                    ( Util.largeLoader, text "" )

                _ ->
                    ( text "", text "" )

        markdown =
            [ buildPreview
            , navTabs
            , viewPipeline_ model msgs ref 
            ]
    in
    div [ Util.testAttribute "full-build" ] markdown


{-| viewPipeline\_ : takes model and renders collapsible template previews and the pipeline configuration file for the desired ref.
-}
viewPipeline_ : PartialModel a -> Msgs msg -> Maybe Ref-> Html msg
viewPipeline_ model msgs ref =
    div [ class "pipeline" ]
        [ viewPipelineTemplates model.templates
        , viewPipelineConfiguration model msgs ref
        ]


{-| viewPipelineTemplates : takes templates and renders a list above the pipeline configuration.
-}
viewPipelineTemplates : ( WebData Templates, Error ) -> Html msg
viewPipelineTemplates templates =
    case templates of
        ( NotAsked, _ ) ->
            text ""

        ( Loading, _ ) ->
            Util.smallLoaderWithText "loading pipeline templates"

        ( Success t, _ ) ->
            viewTemplates t

        ( Failure _, err ) ->
            viewTemplatesError err


{-| viewTemplates : takes templates and renders a list of templates.

    Does not show if no templates are used in the pipeline.

-}
viewTemplates : Templates -> Html msg
viewTemplates templates =
    if not <| Dict.isEmpty templates then
        templates
            |> Dict.toList
            |> List.map viewTemplate
            |> viewTemplatesDetails (class "-success")

    else
        text ""


{-| viewTemplates : renders an error from fetching templates.
-}
viewTemplatesError : Error -> Html msg
viewTemplatesError err =
    [ text <| "There was a problem fetching templates for this pipeline configuration"
    , div [ Util.testAttribute "pipeline-templates-error" ] [ text err ]
    ]
        |> viewTemplatesDetails (class "-error")


{-| viewTemplatesDetails : takes templates content and wraps it in a details/summary.
-}
viewTemplatesDetails : Html.Attribute msg -> List (Html msg) -> Html msg
viewTemplatesDetails cls content =
    Html.details
        [ class "details"
        , class "templates"
        , Html.Attributes.attribute "open" ""
        , Util.testAttribute "pipeline-templates"
        ]
        ([ Html.summary [ class "summary" ]
            [ div [] [ text "Templates" ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
         ]
            ++ [ div [ class "content", cls ] content ]
        )


{-| viewTemplate : takes template and renders view with name, source and HTML url.
-}
viewTemplate : ( String, Template ) -> Html msg
viewTemplate ( _, t ) =
    div [ class "template", Util.testAttribute <| "pipeline-template-" ++ t.name ]
        [ div [] [ strong [] [ text "Name:" ], strong [] [ text "Source:" ], strong [] [ text "Link:" ] ]
        , div []
            [ span [] [ text t.name ]
            , span [] [ text t.source ]
            , a
                [ Html.Attributes.target "_blank"
                , Html.Attributes.href t.link
                ]
                [ text t.link ]
            ]
        ]


{-| viewPipelineConfiguration : takes model and renders a wrapper view for a pipeline configuration if Success or Failure.
-}
viewPipelineConfiguration : PartialModel a -> Msgs msg -> Maybe Ref -> Html msg
viewPipelineConfiguration model msgs ref =
    case model.pipeline.config of
        ( Loading, _ ) ->
            Util.smallLoaderWithText "loading pipeline configuration"

        ( NotAsked, _ ) ->
            text ""

        _ ->
            viewPipelineConfigurationResponse model msgs ref 


{-| viewPipelineConfiguration : takes model and renders view for a pipeline configuration.
-}
viewPipelineConfigurationResponse : PartialModel a ->  Msgs msg ->Maybe Ref-> Html msg
viewPipelineConfigurationResponse model  msgs ref =
    -- TODO: modularize logs rendering
    div [ class "logs-container", class "-pipeline" ]
        [ case model.pipeline.config of
            ( Success config, _ ) ->
                viewPipelineConfigurationData model msgs ref config

            ( Failure _, err ) ->
                viewPipelineConfigurationError model msgs ref err

            _ ->
                text ""
        ]


{-| viewPipelineConfigurationData : takes model and config and renders view for a pipeline configuration's data.
-}
viewPipelineConfigurationData : PartialModel a -> Msgs msg ->Maybe Ref ->  PipelineConfig -> Html msg
viewPipelineConfigurationData model msgs ref config =
    wrapPipelineConfigurationContent model msgs ref (class "") <|
        div [ class "logs", Util.testAttribute "pipeline-configuration-data" ] <|
            viewLines config model.pipeline.lineFocus model.shift msgs.focusLineNumber


{-| viewPipelineConfigurationData : takes model and string and renders a pipeline configuration error.
-}
viewPipelineConfigurationError : PartialModel a -> Msgs msg -> Maybe Ref ->  Error -> Html msg
viewPipelineConfigurationError model msgs ref err =
    wrapPipelineConfigurationContent model msgs ref (class "-error") <|
        div [ class "content", Util.testAttribute "pipeline-configuration-error" ]
            [ text <| "There was a problem fetching the pipeline configuration:", div [] [ text err ] ]


{-| wrapPipelineConfigurationContent : takes model, pipeline configuration and content and wraps it with a table, title and the template expansion header.
-}
wrapPipelineConfigurationContent : PartialModel a -> Msgs msg ->Maybe Ref ->  Html.Attribute msg -> Html msg -> Html msg
wrapPipelineConfigurationContent model { get, expand }  ref cls content =
    let
        body =
            [ div [ class "header" ]
                [ span []
                    [ text "Pipeline Configuration"
                       , case ref of 
                            Just r ->
                                span [ class "link" ] [ text <| "("++ r ++")" ]
                            Nothing -> 
                                text ""
                    ]
                ]
            , viewTemplatesExpansion model get expand
            ]
                ++ [ content ]
    in
    Html.table
        [ class "logs-table"
        , cls
        ]
        body


{-| viewTemplatesExpansion : takes model and renders the config header button for expanding pipeline templates.
-}
viewTemplatesExpansion : PartialModel a -> Get msg -> Expand msg -> Html msg
viewTemplatesExpansion model get expand =
    case model.templates of
        ( Success templates, _ ) ->
            if Dict.size templates > 0 then
                div [ class "expand-templates", Util.testAttribute "pipeline-templates-expand" ]
                    [ expandTemplatesToggleIcon model.pipeline
                    , expandTemplatesToggleButton model.pipeline get expand
                    , expandTemplatesTip
                    ]

            else
                text ""

        ( Loading, _ ) ->
            text ""

        _ ->
            text ""


{-| expandTemplatesToggleIcon : takes pipeline and renders icon for toggling templates expansion.
-}
expandTemplatesToggleIcon : Pipeline -> Html msg
expandTemplatesToggleIcon pipeline =
    let
        wrapExpandTemplatesIcon : Icon -> Html msg
        wrapExpandTemplatesIcon i =
            div [ class "icon" ] [ i |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [] ]
    in
    if pipeline.expanding then
        Util.smallLoader

    else if pipeline.expanded then
        wrapExpandTemplatesIcon FeatherIcons.checkCircle

    else
        wrapExpandTemplatesIcon FeatherIcons.circle


{-| expandTemplatesToggleButton : takes pipeline and renders button that toggles templates expansion.
-}
expandTemplatesToggleButton : Pipeline -> Get msg -> Expand msg -> Html msg
expandTemplatesToggleButton pipeline get expand =
    let
        { org, repo, buildNumber, ref } =
            pipeline

        action =
            if pipeline.expanded then
                get org repo buildNumber ref True

            else
                expand org repo buildNumber ref True
    in
    button
        [ class "button"
        , class "-link"
        , Util.onClickPreventDefault <| action
        , Util.testAttribute "pipeline-templates-expand-toggle"
        ]
        [ if pipeline.expanded then
            text "revert template expansion"

          else
            text "expand templates"
        ]


{-| expandTemplatesTip : renders help tip that is displayed next to the expand templates button.
-}
expandTemplatesTip : Html msg
expandTemplatesTip =
    small [ class "tip" ] [ text "note: yaml fields will be sorted alphabetically when expanding templates." ]



-- LINE FOCUS
-- TODO: modularize logs rendering


{-| viewLineS : takes pipeline configuration, line focus and shift key.

    returns a list of rendered data lines with focusable line numbers.

-}
viewLines : PipelineConfig -> LogFocus -> Bool -> FocusLineNumber msg -> List (Html msg)
viewLines config lineFocus shift focusLineNumber =
    config.data
        |> decodeAnsi
        |> Array.indexedMap
            (\idx line ->
                Just <|
                    viewLine "0"
                        (idx + 1)
                        (Just line)
                        "0"
                        lineFocus
                        shift
                        focusLineNumber
            )
        |> Array.toList
        |> Just
        |> Maybe.withDefault []
        |> List.filterMap identity


{-| viewLine : takes line and focus information and renders line number button and data.
-}
viewLine : ResourceID -> Int -> Maybe Ansi.Log.Line -> String -> LogFocus -> Bool -> FocusLineNumber msg -> Html msg
viewLine id lineNumber line resource lineFocus shiftDown focus =
    tr
        [ Html.Attributes.id <|
            id
                ++ ":"
                ++ String.fromInt lineNumber
        , class "line"
        ]
        [ case line of
            Just l ->
                div
                    [ class "wrapper"
                    , Util.testAttribute <| String.join "-" [ "config", "line", resource, String.fromInt lineNumber ]
                    , class <| lineFocusStyles lineFocus lineNumber
                    ]
                    [ td []
                        [ lineFocusButton resource lineFocus lineNumber shiftDown focus ]
                    , td [ class "break-text", class "overflow-auto" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "config", "data", resource, String.fromInt lineNumber ] ]
                            [ Ansi.Log.viewLine l
                            ]
                        ]
                    ]

            Nothing ->
                text ""
        ]


{-| lineFocusButton : renders button for focusing log line ranges.
-}
lineFocusButton : Resource -> LogFocus -> Int -> Bool -> FocusLineNumber msg -> Html msg
lineFocusButton resource logFocus lineNumber shiftDown focus =
    button
        [ Util.onClickPreventDefault <|
            focus <|
                lineNumber
        , Util.testAttribute <| String.join "-" [ "config", "line", "num", resource, String.fromInt lineNumber ]
        , Html.Attributes.id <| resourceAndLineToFocusId "config" resource lineNumber
        , class "line-number"
        , class "button"
        , class "-link"
        , attribute "aria-label" <| "focus resource " ++ resource
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]
