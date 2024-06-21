{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Admin.Workers exposing (Model, Msg, page)

import Api.Pagination
import Auth
import Components.Loading
import Components.Pager
import Components.Table
import Components.Workers
import Dict
import Effect exposing (Effect)
import Html
    exposing
        ( Html
        , a
        , div
        , span
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( class
        , href
        )
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


{-| page : shared model, route, and returns the page.
-}
page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


{-| toLayout : takes model and passes the page info to Layouts.
-}
toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default_Admin
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "List Workers"
              , content = "vela get workers"
              , docs = Just "cli/worker/get"
              }
            ]
        , crumbs =
            [ ( "Admin", Nothing )
            ]
        }



-- INIT


{-| Model : alias for model for the page.
-}
type alias Model =
    { workers : WebData (List Vela.Worker)
    , pager : List WebLink
    }


{-| init : initializes page with no arguments.
-}
init : Shared.Model -> Route () -> () -> ( Model, Effect Msg )
init shared route () =
    ( { workers = RemoteData.Loading
      , pager = []
      }
    , Effect.getWorkers
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetWorkersResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        }
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = -- WORKERS
      GetWorkersResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Worker ))
    | GotoPage Int
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes current models, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- WORKERS
        GetWorkersResponse response ->
            case response of
                Ok ( meta, workers ) ->
                    ( { model
                        | workers = RemoteData.Success workers
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | workers = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.replaceRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getWorkers
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetWorkersResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    }
                ]
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getWorkers
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetWorkersResponse
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                }
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


{-| view : takes models, route, and creates the html for the page.
-}
view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
    { title = ""
    , body =
        [ Components.Workers.view shared
            { workers = model.workers
            , gotoPage = GotoPage
            , pager = model.pager
            }
        , Components.Pager.view
            { show = True
            , links = model.pager
            , labels = Components.Pager.defaultLabels
            , msg = GotoPage
            }
        ]
    }
