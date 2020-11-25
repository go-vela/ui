{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Update exposing (expandActiveStep, getAllBuildSteps, getBuild, getBuildStepLogs, getBuildStepsLogs, mergeSteps, refreshBuild, refreshBuildSteps, refreshLogs, update)

import Alerts exposing (Alert)
import Api
import Browser.Dom as Dom
import Browser.Navigation as Navigation
import Errors exposing (addError, toFailure)
import File.Download as Download
import Focus exposing (focusFragmentToFocusId, resourceFocusFragment)
import Interop
import Json.Encode as Encode
import List.Extra exposing (updateIf)
import Pages.Build.Logs exposing (focusStep, getCurrentStep, stepBottomTrackerFocusId)
import Pages.Build.Model
    exposing
        ( GetLogs
        , Msg(..)
        , PartialModel
        )
import RemoteData exposing (RemoteData(..), WebData)
import Task
import Toasty as Alerting
import Util exposing (overwriteById)
import Vela
    exposing
        ( BuildNumber
        , FocusFragment
        , Log
        , Logs
        , Org
        , Repo
        , Step
        , StepNumber
        , Steps
        , shouldRefreshBuild
        , statusToFavicon
        )



-- UPDATE


update : PartialModel a -> Msg -> ( PartialModel a, Cmd Msg )
update model msg =
    case msg of
        ExpandStep org repo buildNumber stepNumber ->
            let
                ( steps, fetchStepLogs ) =
                    clickStep model.steps stepNumber

                action =
                    if fetchStepLogs then
                        getBuildStepLogs model org repo buildNumber stepNumber Nothing True

                    else
                        Cmd.none

                stepOpened =
                    isViewingStep steps stepNumber

                -- step clicked is step being followed
                onFollowedStep =
                    model.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)

                follow =
                    if onFollowedStep && not stepOpened then
                        -- stop following a step when collapsed
                        0

                    else
                        model.followingStep
            in
            ( { model | steps = steps, followingStep = follow }
            , Cmd.batch <|
                [ action
                , if stepOpened then
                    Navigation.pushUrl model.navigationKey <| resourceFocusFragment "step" stepNumber []

                  else
                    Cmd.none
                ]
            )

        BuildResponse org repo _ response ->
            case response of
                Ok ( _, build ) ->
                    ( { model
                        | build = RemoteData.succeed build
                        , favicon = statusToFavicon build.status
                      }
                    , Interop.setFavicon <| Encode.string <| statusToFavicon build.status
                    )

                Err error ->
                    ( { model | build = toFailure error }, addError error Error )

        StepResponse _ _ _ _ response ->
            case response of
                Ok ( _, step ) ->
                    ( updateStep model step, Cmd.none )

                Err error ->
                    ( model, addError error Error )

        StepsResponse org repo buildNumber logFocus refresh response ->
            case response of
                Ok ( _, steps ) ->
                    let
                        mergedSteps =
                            steps
                                |> List.sortBy .number
                                |> mergeSteps logFocus refresh model.steps

                        updatedModel =
                            { model | steps = RemoteData.succeed mergedSteps }

                        action =
                            getBuildStepsLogs updatedModel org repo buildNumber mergedSteps logFocus refresh
                    in
                    ( { updatedModel | steps = RemoteData.succeed mergedSteps }, action )

                Err error ->
                    ( model, addError error Error )

        StepLogResponse stepNumber logFocus refresh response ->
            case response of
                Ok ( _, incomingLog ) ->
                    let
                        following =
                            model.followingStep /= 0

                        onFollowedStep =
                            model.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)

                        ( steps, focusId ) =
                            if following && refresh && onFollowedStep then
                                ( model.steps
                                    |> RemoteData.unwrap model.steps
                                        (\s -> expandActiveStep stepNumber s |> RemoteData.succeed)
                                , stepBottomTrackerFocusId <| String.fromInt model.followingStep
                                )

                            else if not refresh then
                                ( model.steps, Util.extractFocusIdFromRange <| focusFragmentToFocusId "step" logFocus )

                            else
                                ( model.steps, "" )

                        cmd =
                            if not <| String.isEmpty focusId then
                                Util.dispatch <| FocusOn <| focusId

                            else
                                Cmd.none
                    in
                    ( { model | logs = updateLogs model.logs incomingLog }
                    , cmd
                    )

                Err error ->
                    ( model, addError error Error )

        FocusLogs url ->
            ( model
            , Navigation.pushUrl model.navigationKey url
            )

        DownloadLogs filename logs ->
            ( model
            , Download.string filename "text" logs
            )

        FollowStep step ->
            ( { model | followingStep = step }
            , Cmd.none
            )

        CollapseAllSteps ->
            let
                steps =
                    model.steps
                        |> RemoteData.unwrap model.steps
                            (\steps_ -> steps_ |> setAllStepViews False |> RemoteData.succeed)
            in
            ( { model | steps = steps, followingStep = 0 }
            , Cmd.none
            )

        ExpandAllSteps org repo buildNumber ->
            let
                steps =
                    RemoteData.unwrap model.steps
                        (\steps_ -> steps_ |> setAllStepViews True |> RemoteData.succeed)
                        model.steps

                -- refresh logs for expanded steps
                action =
                    getBuildStepsLogs model org repo buildNumber (RemoteData.withDefault [] steps) Nothing True
            in
            ( { model | steps = steps }
            , action
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

        Error error ->
            ( model, Cmd.none )
                |> Alerting.addToastIfUnique Alerts.errorConfig AlertsUpdate (Alerts.Error "Error" error)

        AlertsUpdate subMsg ->
            Alerting.update Alerts.successConfig AlertsUpdate subMsg model


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


{-| stepsIds : extracts Ids from list of steps and returns List Int
-}
stepsIds : Steps -> List Int
stepsIds steps =
    List.map (\step -> step.number) steps


{-| updateStep : takes model and incoming step and updates the list of steps if necessary
-}
updateStep : PartialModel a -> Step -> PartialModel a
updateStep model incomingStep =
    let
        steps =
            case model.steps of
                Success s ->
                    s

                _ ->
                    []

        stepExists =
            List.member incomingStep.number <| stepsIds steps

        following =
            model.followingStep /= 0
    in
    if stepExists then
        { model
            | steps =
                steps
                    |> updateIf (\step -> incomingStep.number == step.number)
                        (\step ->
                            let
                                shouldView =
                                    following
                                        && (step.status /= Vela.Pending)
                                        && (step.number == getCurrentStep steps)
                            in
                            { incomingStep
                                | viewing = step.viewing || shouldView
                            }
                        )
                    |> RemoteData.succeed
        }

    else
        { model | steps = RemoteData.succeed <| incomingStep :: steps }


{-| updateLogs : takes model and incoming log and updates the list of logs if necessary
-}
updateLogs : Logs -> Log -> Logs
updateLogs logs incomingLog =
    let
        logExists =
            List.member incomingLog.id <| logIds logs
    in
    if logExists then
        updateLog incomingLog logs

    else if incomingLog.id /= 0 then
        addLog incomingLog logs

    else
        logs


{-| updateLogs : takes incoming log and logs and updates the appropriate log data
-}
updateLog : Log -> Logs -> Logs
updateLog incomingLog logs =
    updateIf
        (\log ->
            case log of
                Success log_ ->
                    incomingLog.id == log_.id && incomingLog.rawData /= log_.rawData

                _ ->
                    True
        )
        (\log -> RemoteData.succeed { incomingLog | decodedLogs = Util.base64Decode incomingLog.rawData })
        logs


{-| logIds : extracts Ids from list of logs and returns List Int
-}
logIds : Logs -> List Int
logIds logs =
    List.map (\log -> log.id) <| Util.successful logs


{-| addLog : takes incoming log and logs and adds log when not present
-}
addLog : Log -> Logs -> Logs
addLog incomingLog logs =
    RemoteData.succeed { incomingLog | decodedLogs = Util.base64Decode incomingLog.rawData } :: logs


getBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Cmd Msg
getBuild model org repo buildNumber =
    Api.try (BuildResponse org repo buildNumber) <| Api.getBuild model org repo buildNumber


getAllBuildSteps : PartialModel a -> Org -> Repo -> BuildNumber -> FocusFragment -> Bool -> Cmd Msg
getAllBuildSteps model org repo buildNumber logFocus refresh =
    Api.tryAll (StepsResponse org repo buildNumber logFocus refresh) <| Api.getAllSteps model org repo buildNumber


getBuildStepLogs : PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Bool -> Cmd Msg
getBuildStepLogs model org repo buildNumber stepNumber logFocus refresh =
    Api.try (StepLogResponse stepNumber logFocus refresh) <| Api.getStepLogs model org repo buildNumber stepNumber


getBuildStepsLogs : PartialModel a -> Org -> Repo -> BuildNumber -> Steps -> FocusFragment -> Bool -> Cmd Msg
getBuildStepsLogs model org repo buildNumber steps logFocus refresh =
    Cmd.batch <|
        List.map
            (\step ->
                if step.viewing then
                    getBuildStepLogs model org repo buildNumber (String.fromInt step.number) logFocus refresh

                else
                    Cmd.none
            )
            steps


{-| refreshBuild : takes model org repo and build number and refreshes the build status
-}
refreshBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Cmd Msg
refreshBuild model org repo buildNumber =
    let
        refresh =
            getBuild model org repo buildNumber
    in
    if shouldRefreshBuild model.build then
        refresh

    else
        Cmd.none


{-| refreshBuildSteps : takes model org repo and build number and refreshes the build steps based on step status
-}
refreshBuildSteps : PartialModel a -> Org -> Repo -> BuildNumber -> FocusFragment -> Cmd Msg
refreshBuildSteps model org repo buildNumber focusFragment =
    if shouldRefreshBuild model.build then
        getAllBuildSteps model org repo buildNumber focusFragment True

    else
        Cmd.none


{-| refreshLogs : takes model org repo and build number and steps and refreshes the build step logs depending on their status
-}
refreshLogs : PartialModel a -> Org -> Repo -> BuildNumber -> WebData Steps -> FocusFragment -> Cmd Msg
refreshLogs model org repo buildNumber inSteps focusFragment =
    let
        stepsToRefresh =
            case inSteps of
                Success s ->
                    -- Do not refresh logs for a step in success or failure state
                    List.filter (\step -> step.status /= Vela.Success && step.status /= Vela.Failure) s

                _ ->
                    []

        refresh =
            getBuildStepsLogs model org repo buildNumber stepsToRefresh focusFragment True
    in
    if shouldRefreshBuild model.build then
        refresh

    else
        Cmd.none
