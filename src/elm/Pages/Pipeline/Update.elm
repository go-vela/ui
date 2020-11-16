{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Update exposing (load, update)

import Alerts exposing (Alert)
import Api
import Browser.Navigation as Navigation
import Errors exposing (addError, detailedErrorToString, toFailure)
import Focus exposing (..)
import Http
import Http.Detailed
import Pages
import Pages.Pipeline.Api exposing (expandPipelineConfig, getPipelineConfig, getPipelineTemplates)
import Pages.Pipeline.Model exposing (Msg(..), PartialModel)
import RemoteData exposing (RemoteData(..))
import Routes
import Svg exposing (line)
import Toasty as Alerting exposing (Stack)
import Vela exposing (LogFocus, Org, Repo, Templates)



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
                        Cmd.batch [ expandPipelineConfig model org repo ref, getPipelineTemplates model org repo ref ]

                    else
                        getPipelineConfig model org repo ref

                Nothing ->
                    getPipelineConfig model org repo ref

        parsed =
            parseFocusFragment lineFocus
    in
    ( { model
        | page = Pages.Pipeline org repo ref expand lineFocus
        , pipeline =
            { config = ( Loading, "" )
            , expanded = False
            , configLoading = True
            , org = org
            , repo = repo
            , ref = ref
            , expand = expand
            , lineFocus = ( parsed.lineA, parsed.lineB )
            }
      }
    , Cmd.batch
        [ getPipelineConfigAction
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
        GetPipelineConfig org repo ref ->
            ( { model | pipeline = { pipeline | configLoading = True } }
            , Cmd.batch
                [ getPipelineConfig model org repo ref
                , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.Pipeline org repo ref Nothing Nothing
                ]
            )

        ExpandPipelineConfig org repo ref ->
            ( { model | pipeline = { pipeline | configLoading = True } }
            , Cmd.batch
                [ expandPipelineConfig model org repo ref
                , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.Pipeline org repo ref (Just "true") Nothing
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
                                , configLoading = False
                            }
                      }
                    , Cmd.batch [ getPipelineTemplates model org repo ref ]
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
                Ok ( meta, config ) ->
                    let
                        ( t, a ) =
                            case model.templates of
                                ( Success _, _ ) ->
                                    ( Tuple.first model.templates, Cmd.none )

                                _ ->
                                    ( Loading, Cmd.batch [ getPipelineTemplates model org repo ref ] )
                    in
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( RemoteData.succeed { data = config }, "" )
                                , expanded = True
                                , configLoading = False
                            }
                        , templates = ( t, "" )
                      }
                    , a
                    )

                Err error ->
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( Errors.toFailure error, detailedErrorToString error )
                                , configLoading = False
                                , expanded = True
                            }
                      }
                    , addError error Error
                    )

        PipelineTemplatesResponse org repo response ->
            case response of
                Ok ( meta, templates ) ->
                    ( { model
                        | templates = ( RemoteData.succeed templates, "" )
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | templates = ( toFailure error, detailedErrorToString error ) }, addError error Error )

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
