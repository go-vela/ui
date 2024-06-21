{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Worker exposing (..)

import Auth
import Browser.Events
import Components.Pager
import Components.Svgs
import Components.Workers
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Graph exposing (Edge, Node)
import Html exposing (button, div, input, label, li, text, ul)
import Html.Attributes exposing (checked, class, for, id, placeholder, title, type_, value)
import Html.Events exposing (onCheck, onClick, onInput)
import Http
import Http.Detailed
import Interop
import Layouts
import Page exposing (Page)
import Pages.Account.Login exposing (Msg(..))
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg
import Svg.Attributes
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)
import Visualization.DOT as DOT


{-| page : takes user, shared model, route, and returns a build's graph (a.k.a. visualize) page.
-}
page : Auth.User -> Shared.Model -> Route { org : String, repo : String, build : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


{-| toLayout : takes user, route, model, and passes a build graph (a.k.a. visualize) page info to Layouts.
-}
toLayout : Auth.User -> Route { org : String, repo : String, build : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Build
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "View Build"
              , content =
                    "vela view build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/view"
              }
            , { name = "Approve Build"
              , content =
                    "vela approve build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/approve"
              }
            , { name = "Restart Build"
              , content =
                    "vela restart build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/restart"
              }
            , { name = "Cancel Build"
              , content =
                    "vela cancel build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/cancel"
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org__Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "#" ++ route.params.build, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        , build = route.params.build
        , toBuildPath =
            \build ->
                Route.Path.Org__Repo__Build__Worker
                    { org = route.params.org
                    , repo = route.params.repo
                    , build = build
                    }
        }



-- INIT


{-| Model : alias for a model object for a build's graph (a.k.a. visualize) page.
-}
type alias Model =
    { build : WebData Vela.Build
    , worker : WebData Vela.Worker
    }


{-| init : takes shared model, route, and initializes build graph (a.k.a. visualize) page input arguments.
-}
init : Shared.Model -> Route { org : String, repo : String, build : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { build = RemoteData.Loading
      , worker = RemoteData.Loading
      }
    , Effect.getWorker
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetWorkerResponse

        -- , org = route.params.org
        -- , repo = route.params.repo
        -- , build = route.params.build
        , worker = "worker1"
        }
      -- TODO: fetch worker information
      -- Effect.getBuildWorker
      --     { baseUrl = shared.velaAPIBaseURL
      --     , session = shared.session
      --     , onResponse = GetBuildGraphResponse { freshDraw = True }
      --     , org = route.params.org
      --     , repo = route.params.repo
      --     , build = route.params.build
      --     }
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = NoOp
      -- WORKER
    | GetWorkerResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Worker ))
      -- REFRESH
    | Tick { interval : Interval.Interval, time : Time.Posix }


{-| update : takes current models, route info, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String, repo : String, build : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        -- WORKER
        GetWorkerResponse response ->
            case response of
                Ok ( _, worker ) ->
                    ( { model | worker = RemoteData.succeed worker }
                    , Effect.none
                    )

                Err error ->
                    ( { model | worker = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns the subscriptions for auto refreshing page or refreshing due to user interaction.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Interval.tickEveryOneSecond Tick
        ]



-- VIEW


{-| view : takes models, route, and creates the html for the page.
-}
view : Shared.Model -> Route { org : String, repo : String, build : String } -> Model -> View Msg
view shared route model =
    { title = "Worker"
    , body =
        [ Components.Workers.viewSingle shared
            { worker = model.worker
            }
        ]
    }
