{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_ exposing (Model, Msg, page, view)

import Auth
import Components.Builds
import Effect exposing (Effect)
import Http
import Http.Detailed
import Layouts
import List
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Utils.Helpers as Util
import Vela exposing (BuildNumber, Org, Repo)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default
        { navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { builds : WebData Vela.Builds
    , showActionsMenus : List Int
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { builds = RemoteData.Loading
      , showActionsMenus = []
      }
    , Effect.getOrgRepoBuilds
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetOrgRepoBuildsResponse
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = GetOrgRepoBuildsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ))
    | ApproveBuild Org Repo BuildNumber
    | RestartBuild Org Repo BuildNumber
    | CancelBuild Org Repo BuildNumber
    | ShowHideActionsMenus (Maybe Int) (Maybe Bool)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        GetOrgRepoBuildsResponse response ->
            case response of
                Ok ( _, builds ) ->
                    ( { model | builds = RemoteData.Success builds }
                    , Effect.none
                    )

                Err error ->
                    -- todo: handle GET builds errors
                    ( model
                    , Effect.none
                    )

        ApproveBuild _ _ _ ->
            ( model, Effect.none )

        RestartBuild _ _ _ ->
            ( model, Effect.none )

        CancelBuild _ _ _ ->
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

        body =
            Components.Builds.view shared
                { msgs = msgs
                , builds = model.builds
                , showActionsMenus = model.showActionsMenus
                , maybeEvent = Nothing
                , showFullTimestamps = True
                }
    in
    { title = route.params.org ++ "/" ++ route.params.repo
    , body =
        [ body
        ]
    }
