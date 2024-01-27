{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Schedules.Add exposing (Model, Msg, page, view)

import Auth
import Components.Form
import Components.ScheduleForm
import Effect exposing (Effect)
import Html exposing (div, em, h2, span, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import Route exposing (Route)
import Shared
import String.Extra
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { utilButtons = []
        , navButtons = []
        }



-- INIT


type alias Model =
    { name : String
    , entry : String
    , enabled : Bool
    , branch : String
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { name = ""
      , entry = ""
      , enabled = True
      , branch = ""
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = AddRepoScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Schedule ))
    | NameOnInput String
    | EntryOnInput String
    | BranchOnInput String
    | EnabledOnClick String
    | SubmitForm


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        AddRepoScheduleResponse response ->
            case response of
                Ok ( _, schedule ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = schedule.name ++ " added to repo schedules."
                        , addToastIfUnique = True
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        NameOnInput val ->
            ( { model | name = val }
            , Effect.none
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
            , Effect.addRepoSchedule
                { baseUrl = shared.velaAPI
                , session = shared.session
                , onResponse = AddRepoScheduleResponse
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


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Add Schedule"
    , body =
        [ div [ class "manage-schedule", Util.testAttribute "manage-schedule" ]
            [ div []
                [ h2 [] [ text <| String.Extra.toTitleCase <| "add repo schedule" ]
                , div [ class "schedule-form" ]
                    [ Components.Form.viewInput
                        { title = Just "Name"
                        , subtitle = Nothing
                        , id_ = "name"
                        , val = model.name
                        , placeholder_ = "Schedule Name"
                        , classList_ = [ ( "schedule-name", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = NameOnInput
                        , disabled_ = False
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
                        , disabled_ = False
                        }
                    , Components.ScheduleForm.viewEnabledInput
                        { msg = EnabledOnClick
                        , value = model.enabled
                        , disabled_ = False
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
                        , disabled_ = False
                        }
                    , Components.ScheduleForm.viewHelp
                    , Components.ScheduleForm.viewSubmitButton
                        { msg = SubmitForm
                        , disabled_ = False
                        }
                    ]
                ]
            ]
        ]
    }
