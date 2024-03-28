{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Admin exposing (Model, Msg, Props, layout, map)

import Components.Crumbs
import Components.Help
import Components.Loading
import Components.Nav
import Components.Tabs
import Components.Util
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, main_)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layout exposing (Layout)
import Layouts.Default
import RemoteData
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Url exposing (Url)
import Utils.Errors as Errors
import Utils.Interval as Interval
import Vela
import View exposing (View)


type alias Props contentMsg =
    { navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    , helpCommands : List Components.Help.Command
    , crumbs : List Components.Crumbs.Crumb
    }


map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.utilButtons
    , helpCommands = props.helpCommands
    , crumbs = props.crumbs
    }


layout : Props contentMsg -> Shared.Model -> Route () -> Layout Layouts.Default.Props Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init props shared route
        , update = update props shared route
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withOnUrlChanged OnUrlChanged
        |> Layout.withParentProps
            { helpCommands = props.helpCommands
            }



-- MODEL


type alias Model =
    { tabHistory : Dict String Url }


init : Props contentMsg -> Shared.Model -> Route () -> () -> ( Model, Effect Msg )
init props shared route _ =
    ( { tabHistory = Dict.empty
      }
    , case shared.user of
        RemoteData.Success user ->
            if not user.admin then
                Effect.replacePath Route.Path.Home_

            else
                Effect.none

        _ ->
            Effect.getCurrentUser
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetCurrentUserResponse
                }
    )



-- UPDATE


type Msg
    = -- BROWSER
      OnUrlChanged { from : Route (), to : Route () }
      -- USER
    | GetCurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.CurrentUser ))
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Props contentMsg -> Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update props shared route msg model =
    case msg of
        -- BROWSER
        OnUrlChanged options ->
            ( { model
                | tabHistory =
                    model.tabHistory |> Dict.insert (Route.Path.toString options.to.path) options.to.url
              }
            , Effect.replaceRouteRemoveTabHistorySkipDomFocus route
            )

        -- USER
        GetCurrentUserResponse response ->
            case response of
                Ok ( _, user ) ->
                    ( model
                    , if not user.admin then
                        Effect.replacePath Route.Path.Home_

                      else
                        Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getCurrentUser
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetCurrentUserResponse
                }
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    let
        isAdmin =
            RemoteData.unwrap False .admin shared.user
    in
    { title = "Admin " ++ content.title
    , body =
        [ Components.Nav.view shared
            route
            { buttons = props.navButtons
            , crumbs = Components.Crumbs.view route.path props.crumbs
            }
        , main_ [ class "content-wrap" ]
            (if isAdmin then
                Components.Util.view shared
                    route
                    (Components.Tabs.viewAdminTabs
                        shared
                        { currentPath = route.path
                        , tabHistory = model.tabHistory
                        }
                        :: props.utilButtons
                    )
                    :: content.body

             else
                [ Components.Loading.viewSmallLoaderWithText "loading user"
                ]
            )
        ]
    }
