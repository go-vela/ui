{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Update exposing (update)

import Api
import Browser.Dom as Dom
import Browser.Navigation as Navigation
import File.Download as Download
import Focus exposing (Resource, ResourceID, resourceFocusFragment)
import List.Extra
import Pages.Build.Logs exposing (..)
import Pages.Build.Model
    exposing
        ( GetLogs
        , Msg(..)
        , PartialModel
        )
import RemoteData exposing (RemoteData(..), WebData)
import Task
import Util exposing (overwriteById)
import Vela
    exposing
        ( BuildNumber
        , LogFocus
        , Org
        , Repo
        , Resources
        , StepNumber
        , Steps
        , updateBuild
        , updateBuildSteps
        , updateBuildStepsFollowing
        )



-- UPDATE


update : PartialModel a -> Msg -> GetLogs a msg -> (Result Dom.Error () -> msg) -> ( PartialModel a, Cmd msg )
update model msg ( getBuildStepLogs, getBuildStepsLogs ) focusResult =
    let
        rm =
            model.repo

        build =
            rm.build
    in
    case msg of
        ExpandStep org repo buildNumber stepNumber ->
            let
                ( steps, fetchStepLogs ) =
                    clickResource build.steps.steps stepNumber

                action =
                    if fetchStepLogs then
                        getBuildStepLogs model org repo buildNumber stepNumber Nothing True

                    else
                        Cmd.none

                stepOpened =
                    isViewing steps stepNumber

                -- step clicked is step being followed
                onFollowedStep =
                    build.steps.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)

                follow =
                    if onFollowedStep && not stepOpened then
                        -- stop following a step when collapsed
                        0

                    else
                        build.steps.followingStep
            in
            ( { model | repo = rm |> updateBuildSteps steps |> updateBuildStepsFollowing follow }
            , Cmd.batch <|
                [ action
                , if stepOpened then
                    Navigation.pushUrl model.navigationKey <| resourceFocusFragment "step" stepNumber []

                  else
                    Cmd.none
                ]
            )

        FocusLogs url ->
            ( model
            , Navigation.pushUrl model.navigationKey url
            )

        DownloadFile ext filename content ->
            ( model
            , Download.string filename ext content
            )

        FollowStep follow ->
            ( { model | repo = updateBuildStepsFollowing follow rm }
            , Cmd.none
            )

        CollapseAllSteps ->
            let
                steps =
                    build.steps.steps
                        |> RemoteData.unwrap build.steps.steps
                            (\steps_ -> steps_ |> setAllViews False |> RemoteData.succeed)
            in
            ( { model | repo = rm |> updateBuildSteps steps |> updateBuildStepsFollowing 0 }
            , Cmd.none
            )

        ExpandAllSteps org repo buildNumber ->
            let
                steps =
                    RemoteData.unwrap build.steps.steps
                        (\steps_ -> steps_ |> setAllViews True |> RemoteData.succeed)
                        build.steps.steps

                -- refresh logs for expanded steps
                action =
                    getBuildStepsLogs model org repo buildNumber (RemoteData.withDefault [] steps) Nothing True
            in
            ( { model | repo = updateBuildSteps steps rm }
            , action
            )

        FocusOn id ->
            ( model, Dom.focus id |> Task.attempt focusResult )
