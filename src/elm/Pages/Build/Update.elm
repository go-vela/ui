{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Update exposing (expandActiveStep, update)

import Browser.Dom as Dom
import Browser.Navigation as Navigation
import List.Extra
import Pages.Build.Logs exposing (logFocusFragment)
import Pages.Build.Model
    exposing
        ( GetLogs
        , Msg(..)
        , PartialModel
        )
import RemoteData exposing (RemoteData(..), WebData)
import Task
import Vela
    exposing
        ( StepNumber
        , Steps
        )



-- UPDATE


update : PartialModel a -> Msg -> GetLogs a msg -> (Result Dom.Error () -> msg) -> ( PartialModel a, Cmd msg )
update model msg ( getBuildStepLogs, getBuildStepsLogs ) focusResult =
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
            in
            ( { model | steps = steps }
            , Cmd.batch <|
                [ action
                , if stepOpened then
                    Navigation.pushUrl model.navigationKey <| logFocusFragment stepNumber []

                  else
                    Cmd.none
                ]
            )

        FocusLogs url ->
            ( model
            , Navigation.pushUrl model.navigationKey url
            )

        FollowStep step ->
            ( { model | followingStep = step }
            , Cmd.none
            )

        FollowSteps org repo buildNumber expanding ->
            let
                steps =
                    model.steps
                        |> RemoteData.unwrap model.steps
                            (\steps_ -> steps_ |> expandActiveSteps |> RemoteData.succeed)

                action =
                    getBuildStepsLogs model org repo buildNumber (RemoteData.withDefault [] steps) Nothing True
            in
            ( { model | autoExpandSteps = not expanding, steps = steps }
            , action
            )

        CollapseAllSteps ->
            let
                steps =
                    model.steps
                        |> RemoteData.unwrap model.steps
                            (\steps_ -> steps_ |> setAllStepViews False |> RemoteData.succeed)
            in
            ( { model | steps = steps }
            , Cmd.none
            )

        ExpandAllSteps org repo buildNumber ->
            let
                steps =
                    RemoteData.unwrap model.steps
                        (\steps_ -> steps_ |> setAllStepViews True |> RemoteData.succeed)
                        model.steps

                action =
                    getBuildStepsLogs model org repo buildNumber (RemoteData.withDefault [] steps) Nothing True
            in
            ( { model | steps = steps }
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


{-| isViewingStep : takes steps and step number and returns the step viewing state
-}
isViewingStep : WebData Steps -> StepNumber -> Bool
isViewingStep steps stepNumber =
    steps
        |> RemoteData.withDefault []
        |> List.filter (\step -> String.fromInt step.number == stepNumber)
        |> List.map (\step -> step.viewing)
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


{-| expandActiveSteps : takes steps and sets steps viewing state if the step is active
-}
expandActiveSteps : Steps -> Steps
expandActiveSteps steps =
    List.Extra.updateIf
        (\step -> step.status /= Vela.Pending)
        (\step -> { step | viewing = True })
        steps


{-| expandActiveStep : takes steps and sets step viewing state if the step is active
-}
expandActiveStep : StepNumber -> Steps -> Steps
expandActiveStep stepNumber steps =
    List.Extra.updateIf
        (\step -> (String.fromInt step.number == stepNumber) && (step.status /= Vela.Pending))
        (\step -> { step | viewing = True })
        steps
