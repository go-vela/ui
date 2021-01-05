{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Update exposing (load, update)

import Alerts exposing (Alert)
import Api
import Browser.Dom as Dom
import Browser.Navigation as Navigation
import Errors exposing (addError, detailedErrorToString, toFailure)
import File.Download as Download
import Focus exposing (..)
import Http
import Http.Detailed
import Pages exposing (Page)
import Pages.Pipeline.Api exposing (expandPipelineConfig, getPipelineConfig, getPipelineTemplates)
import Pages.Pipeline.Model exposing (Msg(..), PartialModel)
import RemoteData exposing (RemoteData(..))
import Routes
import Svg exposing (line)
import Task
import Toasty as Alerting exposing (Stack)
import Util
import Vela exposing (LogFocus, Org, Repo, RepoResourceIdentifier, Templates)



-- LOAD


{-| load : takes model org, repo, and build number and loads the appropriate pipeline configuration resources.
-}
load : PartialModel a -> Org -> Repo -> Maybe RefQuery -> Maybe ExpandTemplatesQuery -> Maybe Fragment -> ( PartialModel a, Cmd Msg )
load model org repo ref expand lineFocus =
    let
        getPipelineConfigAction =
            case expand of
                Just e ->
                    if e == "true" then
                        expandPipelineConfig model org repo ref

                    else
                        getPipelineConfig model org repo ref

                Nothing ->
                    getPipelineConfig model org repo ref

        parsed =
            parseFocusFragment lineFocus

        sameRef =
            isSamePipelineRef ( org, repo, Maybe.withDefault "" ref ) model.page
    in
    ( { model
        | page = Pages.Pipeline org repo ref expand lineFocus
        , pipeline =
            { config =
                if sameRef then
                    model.pipeline.config

                else
                    ( Loading, "" )
            , expanded = False
            , expanding = True
            , org = org
            , repo = repo
            , ref = ref
            , expand = expand
            , lineFocus = ( parsed.lineA, parsed.lineB )
            , focusFragment =
                case lineFocus of
                    Just l ->
                        Just <| "#" ++ l

                    Nothing ->
                        Nothing
            , buildNumber = Nothing
            }
        , templates =
            if sameRef then
                model.templates

            else
                { data = Loading, error = "", show = True }
      }
    , Cmd.batch
        [ getPipelineConfigAction
        , getPipelineTemplates model org repo ref lineFocus
        ]
    )




-- UPDATE


{-| update : takes model and msg, returns a new model and potential action.
-}
update : PartialModel a -> Msg -> ( PartialModel a, Cmd Msg )
update model msg =
    let
        pipeline =
            model.pipeline
    in
    case msg of
        GetPipelineConfig org repo ref expansionToggle ->
            ( { model
                | pipeline =
                    { pipeline
                        | expanding = True
                    }
              }
            , Cmd.batch
                [ getPipelineConfig model org repo ref
                , Navigation.replaceUrl model.navigationKey <| Routes.routeToUrl <| Routes.Pipeline org repo ref Nothing Nothing
                ]
            )

        ExpandPipelineConfig org repo ref expansionToggle ->
            ( { model
                | pipeline =
                    { pipeline
                        | expanding = True
                    }
              }
            , Cmd.batch
                [ expandPipelineConfig model org repo ref
                , Navigation.replaceUrl model.navigationKey <| Routes.routeToUrl <| Routes.Pipeline org repo ref (Just "true") Nothing
                ]
            )

        GetPipelineConfigResponse org repo ref response ->
            case response of
                Ok ( meta, config ) ->
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( RemoteData.succeed { data = config }, "" )
                                , expanded = False
                                , expanding = False
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( toFailure error, detailedErrorToString error )
                            }
                      }
                    , Errors.addError error Error
                    )

        ExpandPipelineConfigResponse org repo ref response ->
            case response of
                Ok ( _, config ) ->
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( RemoteData.succeed { data = config }, "" )
                                , expanded = True
                                , expanding = False
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( Errors.toFailure error, detailedErrorToString error )
                                , expanding = False
                                , expanded = True
                            }
                      }
                    , addError error Error
                    )

        GetPipelineTemplatesResponse org repo lineFocus response ->
            case response of
                Ok ( meta, templates ) ->
                    ( { model
                        | templates = { data = RemoteData.succeed templates, error = "", show = model.templates.show }
                      }
                    , Util.dispatch <| FocusOn <| Util.extractFocusIdFromRange <| focusFragmentToFocusId "config" lineFocus
                    )

                Err error ->
                    ( { model | templates = { data = toFailure error, error = detailedErrorToString error, show = model.templates.show } }, addError error Error )

        FocusLine line ->
            let
                url =
                    lineRangeId "config" "0" line pipeline.lineFocus model.shift
            in
            ( { model
                | pipeline =
                    { pipeline
                        | lineFocus = pipeline.lineFocus
                    }
              }
            , Navigation.pushUrl model.navigationKey <| url
            )

        Error error ->
            ( model, Cmd.none )
                |> Alerting.addToastIfUnique Alerts.errorConfig AlertsUpdate (Alerts.Error "Error" error)

        AlertsUpdate subMsg ->
            Alerting.update Alerts.successConfig AlertsUpdate subMsg model

        DownloadLogs filename logs ->
            ( model
            , Download.string filename "text" logs
            )

        FocusOn id ->
            ( model, Dom.focus id |> Task.attempt FocusResult )

        FocusResult result ->
            -- handle success or failure here
            case result of
                Err (Dom.NotFound id) ->
                    -- unable to find dom 'id'
                    ( model, Cmd.none )

                Ok ok ->
                    -- successfully focus the dom
                    ( model, Cmd.none )


{-| resourceChanged : takes two repo resource identifiers and returns if the build has changed
-}
resourceChanged : RepoResourceIdentifier -> RepoResourceIdentifier -> Bool
resourceChanged ( orgA, repoA, idA ) ( orgB, repoB, idB ) =
    not <| orgA == orgB && repoA == repoB && idA == idB


{-| isSamePipelineRef : takes two pipeline resource identifiers and returns if the pipeline ref has changed
-}
isSamePipelineRef : RepoResourceIdentifier -> Page -> Bool
isSamePipelineRef id currentPage =
    case currentPage of
        Pages.Pipeline o r rf _ _ ->
            not <| resourceChanged id ( o, r, Maybe.withDefault "" rf )

        _ ->
            False
