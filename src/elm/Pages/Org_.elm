{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_ exposing (Model, Msg, page, view)

import Api.Pagination
import Auth
import Components.Loading
import Components.Pager
import Components.Repo
import Dict
import Effect exposing (Effect)
import Html exposing (a, caption, div, h1, p, span, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors as Errors
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


{-| page : takes user, shared model, route, and returns the org page.
-}
page : Auth.User -> Shared.Model -> Route { org : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


{-| toLayout : takes user, route, model, and passes an org's page info to Layouts.
-}
toLayout : Auth.User -> Route { org : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Org
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = ""
              , content = "resources on this page not yet supported via the CLI"
              , docs = Nothing
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Nothing )
            ]
        , org = route.params.org
        }



-- INIT


{-| Model : alias for a model object for the org page.
-}
type alias Model =
    { repos : WebData (List Vela.Repository)
    , pager : List WebLink
    }


{-| init : takes shared model, route, and initializes org page input arguments.
-}
init : Shared.Model -> Route { org : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { repos = RemoteData.Loading
      , pager = []
      }
    , Effect.getOrgRepos
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetOrgReposResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , org = route.params.org
        }
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = -- REPOS
      GetOrgReposResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Repository ))
    | GotoPage Int
      -- FAVORITES
    | ToggleFavorite Vela.Org (Maybe Vela.Repo)
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes current models, route, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- REPOS
        GetOrgReposResponse response ->
            case response of
                Ok ( meta, repos ) ->
                    ( { model
                        | repos = RemoteData.Success repos
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | repos = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.pushRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getOrgRepos
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetOrgReposResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    }
                ]
            )

        -- FAVORITES
        ToggleFavorite org maybeRepo ->
            ( model
            , Effect.updateFavorite { org = org, maybeRepo = maybeRepo, updateType = Favorites.Toggle }
            )

        -- REFRESH
        Tick options ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns the subscriptions for auto refreshing the page.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


{-| view : takes models, route, and creates the html for the org page.
-}
view : Shared.Model -> Route { org : String } -> Model -> View Msg
view shared route model =
    { title = "Repos" ++ Util.pageToString (Dict.get "page" route.query)
    , body =
        [ caption
            [ class "builds-caption"
            ]
            [ span [] []
            , Components.Pager.view
                { show = RemoteData.unwrap 0 List.length model.repos > 0
                , links = model.pager
                , labels = Components.Pager.prevNextLabels
                , msg = GotoPage
                }
            ]
        , case model.repos of
            RemoteData.Success repos ->
                if List.length repos == 0 then
                    div []
                        [ h1 [] [ text "No Repositories are enabled for this Organization!" ]
                        , p [] [ text "Enable repositories" ]
                        , a
                            [ class "button"
                            , class "-outline"
                            , Util.testAttribute "source-repos"
                            , Route.Path.href Route.Path.Account_SourceRepos
                            ]
                            [ text "Source Repositories" ]
                        ]

                else
                    div [] <|
                        List.map
                            (\repository ->
                                Components.Repo.view
                                    shared
                                    { toggleFavoriteMsg = ToggleFavorite
                                    , org = repository.org
                                    , repo = repository.name
                                    , favorites = RemoteData.unwrap [] .favorites shared.user
                                    , filtered = False
                                    }
                            )
                            repos

            RemoteData.Loading ->
                Components.Loading.viewSmallLoader

            RemoteData.NotAsked ->
                Components.Loading.viewSmallLoader

            RemoteData.Failure _ ->
                div [ Util.testAttribute "repos-error" ]
                    [ p []
                        [ text "There was an error fetching repos, please refresh or try again later!"
                        ]
                    ]
        , Components.Pager.view
            { show = RemoteData.unwrap 0 List.length model.repos > 0
            , links = model.pager
            , labels = Components.Pager.prevNextLabels
            , msg = GotoPage
            }
        ]
    }
