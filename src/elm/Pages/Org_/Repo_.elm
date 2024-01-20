{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_ exposing (Model, Msg, page, view)

import Api.Pagination
import Auth
import Components.Builds
import Components.Pager
import Dict
import Effect exposing (Effect)
import Html exposing (text)
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import List
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Repo
        { org = route.params.org
        , repo = route.params.repo
        , nil = []
        }



-- INIT


type alias Model =
    { builds : WebData (List Vela.Build)
    , pager : List WebLink
    , showFullTimestamps : Bool
    , showActionsMenus : List Int
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { builds = RemoteData.Loading
      , pager = []
      , showFullTimestamps = False
      , showActionsMenus = []
      }
    , Effect.getRepoBuilds
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetRepoBuildsResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , maybeEvent = Dict.get "event" route.query
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = GetRepoBuildsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ))
    | GotoPage Int
    | ApproveBuild Vela.Org Vela.Repo Vela.BuildNumber
    | RestartBuild Vela.Org Vela.Repo Vela.BuildNumber
    | CancelBuild Vela.Org Vela.Repo Vela.BuildNumber
    | ShowHideActionsMenus (Maybe Int) (Maybe Bool)
    | FilterByEvent (Maybe String)
    | ShowHideFullTimestamps


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetRepoBuildsResponse response ->
            case response of
                Ok ( meta, builds ) ->
                    ( { model
                        | builds = RemoteData.Success builds
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | builds = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
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
                , Effect.getRepoBuilds
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetRepoBuildsResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , maybeEvent = Dict.get "event" route.query
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )

        ApproveBuild _ _ _ ->
            let
                _ =
                    Debug.log "approve build clicked" ""

                -- todo:
                -- 1. write func in Effect.elm for "approveBuild"
                -- 2. write Api.Operations.approveBuild that uses it
                --   look at the code in Api.Operations and the other funcs in Api.Operations for inspiration
                -- 3. write ApproveBuildResponse Msg in this file
                -- 4. in ApproveBuildResponse, create a toasty?
                -- look at how it's done in Main.elm
            in
            ( model, Effect.none )

        RestartBuild _ _ _ ->
            let
                _ =
                    Debug.log "restart build clicked" ""
            in
            ( model, Effect.none )

        CancelBuild _ _ _ ->
            let
                _ =
                    Debug.log "cancel build clicked" ""
            in
            ( model, Effect.none )

        ShowHideActionsMenus build show ->
            let
                buildsOpen =
                    model.showActionsMenus

                replaceList : Int -> List Int -> List Int
                replaceList id buildList =
                    if List.member id buildList then
                        []

                    else
                        [ id ]

                updatedOpen : List Int
                updatedOpen =
                    Maybe.Extra.unwrap []
                        (\b ->
                            Maybe.Extra.unwrap
                                (replaceList b buildsOpen)
                                (\_ -> buildsOpen)
                                show
                        )
                        build
            in
            ( { model
                | showActionsMenus = updatedOpen
              }
            , Effect.none
            )

        FilterByEvent maybeEvent ->
            ( { model
                | builds = RemoteData.Loading
                , pager = []
              }
            , Effect.batch
                [ Effect.pushRoute
                    { path = route.path
                    , query =
                        Dict.update "event" (\_ -> maybeEvent) route.query
                    , hash = route.hash
                    }
                , Effect.getRepoBuilds
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetRepoBuildsResponse
                    , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , maybeEvent = maybeEvent
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )

        ShowHideFullTimestamps ->
            ( { model | showFullTimestamps = not model.showFullTimestamps }, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Util.onMouseDownSubscription "build-actions" (List.length model.showActionsMenus > 0) (ShowHideActionsMenus Nothing)



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    let
        msgs =
            { approveBuild = ApproveBuild
            , restartBuild = RestartBuild
            , cancelBuild = CancelBuild
            , showHideActionsMenus = ShowHideActionsMenus
            }
    in
    { title = route.params.org ++ "/" ++ route.params.repo
    , body =
        [ if List.length (RemoteData.withDefault [] model.builds) > 0 then
            Components.Builds.viewHeader
                { maybeEvent = Dict.get "event" route.query
                , showFullTimestamps = model.showFullTimestamps
                , filterByEvent = FilterByEvent
                , showHideFullTimestamps = ShowHideFullTimestamps
                }

          else
            text ""
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        , Components.Builds.view shared
            { msgs = msgs
            , builds = model.builds
            , showActionsMenus = model.showActionsMenus
            , maybeEvent = Dict.get "event" route.query
            , showFullTimestamps = model.showFullTimestamps
            , showActionsMenuBool = True
            }
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        ]
    }
