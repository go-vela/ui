{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Update exposing (Msg(..), load, update)

import Alerts exposing (Alert)
import Api
import Browser.Navigation as Navigation
import Errors exposing (addError, toFailure)
import Focus exposing (..)
import Http
import Http.Detailed
import Pages
import Pages.Pipeline.Model
    exposing
        ( PartialModel
        )
import RemoteData exposing (RemoteData(..))
import Routes
import Svg exposing (line)
import Toasty as Alerting exposing (Stack)
import Vela exposing (LogFocus, Org, Repo, Templates)



-- MSG


type Msg
    = GetPipelineConfig Org Repo (Maybe String)
    | ExpandPipelineConfig Org Repo (Maybe String)
    | GetPipelineConfigResponse Org Repo (Maybe String) (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | ExpandPipelineConfigResponse Org Repo (Maybe String) (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | PipelineTemplatesResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Templates ))
    | FocusLine Int
    | Error String
    | AlertsUpdate (Alerting.Msg Alert)



-- UPDATE


{-| load : takes model org, repo, and build number and loads the appropriate build analysis.
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
    in
    -- Fetch build from Api
    ( { model
        | page = Pages.Pipeline org repo ref expand Nothing
        , pipeline =
            { config = Loading
            , expanded = False
            , configLoading = True
            , org = org
            , repo = repo
            , ref = ref
            , expand = expand
            , lineFocus = ( parsed.lineA, parsed.lineB )
            }
        , templates = Loading
      }
    , Cmd.batch
        [ getPipelineConfigAction
        , getPipelineTemplates model org repo ref
        ]
    )


getPipelineConfig : PartialModel a -> Org -> Repo -> Maybe String -> Cmd Msg
getPipelineConfig model org repo ref =
    Api.tryString (GetPipelineConfigResponse org repo ref) <| Api.getPipelineConfig model org repo ref


expandPipelineConfig : PartialModel a -> Org -> Repo -> Maybe String -> Cmd Msg
expandPipelineConfig model org repo ref =
    Api.tryString (ExpandPipelineConfigResponse org repo ref) <| Api.expandPipelineConfig model org repo ref


getPipelineTemplates : PartialModel a -> Org -> Repo -> Maybe String -> Cmd Msg
getPipelineTemplates model org repo ref =
    Api.try (PipelineTemplatesResponse org repo) <| Api.getPipelineTemplates model org repo ref


update : PartialModel a -> Msg -> ( PartialModel a, Cmd Msg )
update model msg =
    let
        p =
            model.pipeline
    in
    case msg of
        GetPipelineConfig org repo ref ->
            ( { model | pipeline = { p | configLoading = True } }
            , Cmd.batch
                [ getPipelineConfig model org repo ref
                , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.Pipeline org repo ref Nothing Nothing
                ]
            )

        ExpandPipelineConfig org repo ref ->
            ( { model | pipeline = { p | configLoading = True } }
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
                            { p
                                | config = RemoteData.succeed { data = config }
                                , expanded = False
                                , configLoading = False
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | pipeline = { p | config = Errors.toFailure error } }, Errors.addError error Error )

        ExpandPipelineConfigResponse org repo ref response ->
            case response of
                Ok ( meta, config ) ->
                    ( { model
                        | pipeline =
                            { p
                                | config = RemoteData.succeed { data = config }
                                , expanded = True
                                , configLoading = False
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | pipeline = { p | config = toFailure error, configLoading = False, expanded = False } }, addError error Error )

        PipelineTemplatesResponse org repo response ->
            case response of
                Ok ( meta, templates ) ->
                    ( { model
                        | templates = RemoteData.succeed templates
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | templates = toFailure error }, addError error Error )

        FocusLine line ->
            let
                url =
                    lineRangeId "config" "0" line p.lineFocus model.shift
            in
            ( { model | pipeline = { p | lineFocus = p.lineFocus } }
            , Navigation.pushUrl model.navigationKey <| url
            )

        Error error ->
            ( model, Cmd.none )
                |> Alerting.addToastIfUnique Alerts.errorConfig AlertsUpdate (Alerts.Error "Error" error)

        AlertsUpdate subMsg ->
            Alerting.update Alerts.successConfig AlertsUpdate subMsg model
