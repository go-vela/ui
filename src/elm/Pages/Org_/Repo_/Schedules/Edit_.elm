{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Schedules.Edit_ exposing (Model, Msg, page, view)

import Auth
import Components.Form
import Components.ScheduleForm
import Effect exposing (Effect)
import Html exposing (div, em, h2, span, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import String.Extra
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String, name : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String, name : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { navButtons = []
        , utilButtons = []
        , repo = Nothing
        }



-- INIT


type alias Model =
    { schedule : WebData Vela.Schedule
    , name : String
    , entry : String
    , enabled : Bool
    , branch : String
    }


init : Shared.Model -> Route { org : String, repo : String, name : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { schedule = RemoteData.Loading
      , name = ""
      , entry = ""
      , enabled = True
      , branch = ""
      }
    , Effect.getRepoSchedule
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetRepoScheduleResponse
        , org = route.params.org
        , repo = route.params.repo
        , name = route.params.name
        }
    )



-- UPDATE


type Msg
    = NoOp
      -- SCHEDULES
    | GetRepoScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Schedule ))
    | UpdateRepoScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Schedule ))
    | EntryOnInput String
    | BranchOnInput String
    | EnabledOnClick String
    | SubmitForm


update : Shared.Model -> Route { org : String, repo : String, name : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        -- SCHEDULES
        GetRepoScheduleResponse response ->
            case response of
                Ok ( _, schedule ) ->
                    ( { model
                        | schedule = RemoteData.Success schedule
                        , name = schedule.name
                        , entry = schedule.entry
                        , enabled = schedule.enabled
                        , branch = schedule.branch
                      }
                    , Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        UpdateRepoScheduleResponse response ->
            case response of
                Ok ( _, schedule ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = schedule.name ++ " updated in repo schedules."
                        , addToastIfUnique = True
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        EntryOnInput val ->
            ( { model | entry = val }
            , Effect.none
            )

        BranchOnInput val ->
            ( { model | branch = val }
            , Effect.none
            )

        EnabledOnClick val ->
            ( model
                |> (\m -> { m | enabled = Util.yesNoToBool val })
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    Vela.buildSchedulePayload
                        { org = Just route.params.org
                        , repo = Just route.params.repo
                        , name = Util.stringToMaybe model.name
                        , entry = Util.stringToMaybe model.entry
                        , enabled = Just model.enabled
                        , branch = Just model.branch
                        }

                body =
                    Http.jsonBody <| Vela.encodeSchedulePayload payload
            in
            ( model
            , Effect.updateRepoSchedule
                { baseUrl = shared.velaAPI
                , session = shared.session
                , onResponse = UpdateRepoScheduleResponse
                , org = route.params.org
                , repo = route.params.repo
                , name = model.name
                , body = body
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, name : String } -> Model -> View Msg
view shared route model =
    { title = "Add Schedule"
    , body =
        [ div [ class "manage-schedule", Util.testAttribute "manage-schedule" ]
            [ div []
                [ h2 [] [ text <| String.Extra.toTitleCase <| "update repo schedule" ]
                , div [ class "schedule-form" ]
                    [ Components.Form.viewInput
                        { title = Just "Name"
                        , subtitle = Nothing
                        , id_ = "name"
                        , val = RemoteData.unwrap "" .name model.schedule
                        , placeholder_ = "loading..."
                        , classList_ = [ ( "schedule-name", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = \_ -> NoOp
                        , disabled_ = True
                        }
                    , Components.Form.viewTextarea
                        { title = Just "Cron Expression"
                        , subtitle = Just <| Components.ScheduleForm.viewCronHelp shared.time
                        , id_ = "cron"
                        , val = model.entry
                        , placeholder_ = "0 0 * * * (runs at 12:00 AM in UTC)"
                        , classList_ = [ ( "schedule-cron", True ) ]
                        , rows_ = Just 2
                        , wrap_ = Just "soft"
                        , msg = EntryOnInput
                        , disabled_ = not <| RemoteData.isSuccess model.schedule
                        }
                    , Components.ScheduleForm.viewEnabledInput
                        { msg = EnabledOnClick
                        , value = model.enabled
                        , disabled_ = not <| RemoteData.isSuccess model.schedule
                        }
                    , Components.Form.viewInput
                        { title = Just "Branch"
                        , subtitle =
                            Just <|
                                span
                                    [ class "field-description" ]
                                    [ em [] [ text "(Leave blank to use default branch)" ]
                                    ]
                        , id_ = "branch"
                        , val = model.branch
                        , placeholder_ = "Branch Name"
                        , classList_ = [ ( "branch-name", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = BranchOnInput
                        , disabled_ = not <| RemoteData.isSuccess model.schedule
                        }
                    , Components.ScheduleForm.viewHelp shared.velaDocsURL
                    , Components.ScheduleForm.viewSubmitButton
                        { msg = SubmitForm
                        , disabled_ = not <| RemoteData.isSuccess model.schedule
                        }
                    ]
                ]
            ]
        ]
    }
