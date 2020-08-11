{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Update exposing (setStepView, update)

import Browser.Dom as Dom
import Browser.Navigation as Navigation
import List.Extra
import Pages.Build.Logs
    exposing
        ( logFocusFragment
        )
import Pages.Build.Model
    exposing
        ( Msg(..)
        )
import Pages.Build.View exposing (PartialModel)
import RemoteData exposing (RemoteData(..), WebData)
import Task
import Vela
    exposing
        ( BuildNumber
        , FocusFragment
        , Org
        , Repo
        , SecretType(..)
        , StepNumber
        , Steps
        )


type alias GetLogs a msg =
    PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Cmd msg



-- UPDATE


update : PartialModel a -> Msg -> GetLogs a msg -> (Result Dom.Error () -> msg) -> ( PartialModel a, Cmd msg )
update model msg getBuildStepLogs focusResult =
    case msg of
        ExpandStep org repo buildNumber stepNumber _ ->
            let
                ( steps, fetchStepLogs ) =
                    clickStep model.steps stepNumber

                action =
                    if fetchStepLogs then
                        getBuildStepLogs model org repo buildNumber stepNumber Nothing

                    else
                        Cmd.none

                stepOpened =
                    viewingStep steps stepNumber
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

        FollowLogs follow ->
            ( { model | followLogs = follow }
            , Cmd.none
            )

        FocusOn id ->
            ( model, Dom.focus id |> Task.attempt focusResult )


{-| clickStep : takes steps and step number, toggles step view state, and returns whether or not to fetch logs
-}
clickStep : WebData Steps -> StepNumber -> ( WebData Steps, Bool )
clickStep steps stepNumber =
    let
        ( stepsOut, action ) =
            case steps of
                RemoteData.Success steps_ ->
                    ( RemoteData.succeed <| toggleStepView steps_ stepNumber
                    , True
                    )

                _ ->
                    ( steps, False )
    in
    ( stepsOut
    , action
    )


{-| toggleStepView : takes steps and step number and toggles that steps viewing state
-}
toggleStepView : Steps -> String -> Steps
toggleStepView steps stepNumber =
    List.Extra.updateIf
        (\step -> String.fromInt step.number == stepNumber)
        (\step -> { step | viewing = not step.viewing })
        steps


{-| setStepView : takes steps and step number and sets that steps viewing state
-}
setStepView : Steps -> String -> Bool -> Steps
setStepView steps stepNumber value =
    List.Extra.updateIf
        (\step -> String.fromInt step.number == stepNumber)
        (\step -> { step | viewing = value })
        steps


{-| viewingStep : takes steps and step number and returns the step viewing state
-}
viewingStep : WebData Steps -> StepNumber -> Bool
viewingStep steps stepNumber =
    Maybe.withDefault False <|
        List.head <|
            List.map (\step -> step.viewing) <|
                List.filter (\step -> String.fromInt step.number == stepNumber) <|
                    RemoteData.withDefault [] steps
