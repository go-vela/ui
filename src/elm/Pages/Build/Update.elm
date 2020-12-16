{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Update exposing (expandActiveStep, mergeSteps, update)

import Api
import Browser.Dom as Dom
import Browser.Navigation as Navigation
import File.Download as Download
import Focus exposing (resourceFocusFragment)
import List.Extra
import Pages.Build.Logs exposing (focusStep)
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
        , Org
        , Repo
        , StepNumber
        , Steps
        , updateBuild
        , updateBuildStepFollowing
        , updateBuildSteps
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
                    clickStep build.steps stepNumber

                action =
                    if fetchStepLogs then
                        getBuildStepLogs model org repo buildNumber stepNumber Nothing True

                    else
                        Cmd.none

                stepOpened =
                    isViewingStep steps stepNumber

                -- step clicked is step being followed
                onFollowedStep =
                    build.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)

                follow =
                    if onFollowedStep && not stepOpened then
                        -- stop following a step when collapsed
                        0

                    else
                        build.followingStep
            in
            ( { model
                | repo =
                    rm
                        |> updateBuildSteps steps
                        |> updateBuildStepFollowing follow
              }
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

        DownloadLogs filename logs ->
            ( model
            , Download.string filename "text" logs
            )

        FollowStep step ->
            ( { model | repo = updateBuildStepFollowing step rm }
            , Cmd.none
            )

        CollapseAllSteps ->
            let
                steps =
                    build.steps
                        |> RemoteData.unwrap build.steps
                            (\steps_ -> steps_ |> setAllStepViews False |> RemoteData.succeed)
            in
            ( { model
                | repo =
                    rm
                        |> updateBuildSteps steps
                        |> updateBuildStepFollowing 0
              }
            , Cmd.none
            )

        ExpandAllSteps org repo buildNumber ->
            let
                steps =
                    RemoteData.unwrap build.steps
                        (\steps_ -> steps_ |> setAllStepViews True |> RemoteData.succeed)
                        build.steps

                -- refresh logs for expanded steps
                action =
                    getBuildStepsLogs model org repo buildNumber (RemoteData.withDefault [] steps) Nothing True
            in
            ( { model | repo = updateBuildSteps steps rm }
            , action
            )

        FocusOn id ->
            ( model, Dom.focus id |> Task.attempt focusResult )


{-| clickStep : takes steps and step number, toggles step view state, and returns whether or not to fetch logs
-}
clickStep : WebData Steps -> StepNumber -> ( WebData Steps, Bool )
clickStep steps stepNumber =
    let
        ( stepsOut, action ) =
            RemoteData.unwrap ( steps, False )
                (\steps_ ->
                    ( toggleStepView stepNumber steps_ |> RemoteData.succeed
                    , True
                    )
                )
                steps
    in
    ( stepsOut
    , action
    )


{-| mergeSteps : takes takes current steps and incoming step information and merges them, updating old logs and retaining previous state.
-}
mergeSteps : Maybe String -> Bool -> WebData Steps -> Steps -> Steps
mergeSteps logFocus refresh currentSteps incomingSteps =
    let
        updatedSteps =
            currentSteps
                |> RemoteData.unwrap incomingSteps
                    (\steps ->
                        incomingSteps
                            |> List.map
                                (\incomingStep ->
                                    let
                                        ( viewing, focus ) =
                                            getStepInfo steps incomingStep.number
                                    in
                                    overwriteById
                                        { incomingStep
                                            | viewing = viewing
                                            , logFocus = focus
                                        }
                                        steps
                                )
                            |> List.filterMap identity
                    )
    in
    -- when not an automatic refresh, respect the url focus
    if not refresh then
        focusStep logFocus updatedSteps

    else
        updatedSteps


{-| isViewingStep : takes steps and step number and returns the step viewing state
-}
isViewingStep : WebData Steps -> StepNumber -> Bool
isViewingStep steps stepNumber =
    steps
        |> RemoteData.withDefault []
        |> List.filter (\step -> String.fromInt step.number == stepNumber)
        |> List.map .viewing
        |> List.head
        |> Maybe.withDefault False


{-| toggleStepView : takes steps and step number and toggles that steps viewing state
-}
toggleStepView : String -> Steps -> Steps
toggleStepView stepNumber =
    List.Extra.updateIf
        (\step -> String.fromInt step.number == stepNumber)
        (\step -> { step | viewing = not step.viewing })


{-| setAllStepViews : takes steps and value and sets all steps viewing state
-}
setAllStepViews : Bool -> Steps -> Steps
setAllStepViews value =
    List.map (\step -> { step | viewing = value })


{-| expandActiveStep : takes steps and sets step viewing state if the step is active
-}
expandActiveStep : StepNumber -> Steps -> Steps
expandActiveStep stepNumber steps =
    List.Extra.updateIf
        (\step -> (String.fromInt step.number == stepNumber) && (step.status /= Vela.Pending))
        (\step -> { step | viewing = True })
        steps


{-| getStepInfo : takes steps and step number and returns the step update information
-}
getStepInfo : Steps -> Int -> ( Bool, ( Maybe Int, Maybe Int ) )
getStepInfo steps stepNumber =
    steps
        |> List.filter (\step -> step.number == stepNumber)
        |> List.map (\step -> ( step.viewing, step.logFocus ))
        |> List.head
        |> Maybe.withDefault ( False, ( Nothing, Nothing ) )
