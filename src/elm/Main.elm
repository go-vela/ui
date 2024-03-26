{--
SPDX-License-Identifier: Apache-2.0
--}


module Main exposing (main)

import Auth
import Auth.Action
import Browser
import Browser.Navigation
import Dict
import Effect exposing (Effect)
import Interop
import Json.Decode
import Json.Encode
import Layout
import Layouts exposing (Layout)
import Layouts.Default
import Layouts.Default.Build
import Layouts.Default.Org
import Layouts.Default.Repo
import Main.Layouts.Model
import Main.Layouts.Msg
import Main.Pages.Model
import Main.Pages.Msg
import Maybe
import Maybe.Extra
import Page
import Pages.Account.Login
import Pages.Account.Settings
import Pages.Account.SourceRepos
import Pages.Home
import Pages.NotFound_
import Pages.Org_
import Pages.Org_.Builds
import Pages.Org_.Repo_
import Pages.Org_.Repo_.Build_
import Pages.Org_.Repo_.Build_.Graph
import Pages.Org_.Repo_.Build_.Pipeline
import Pages.Org_.Repo_.Build_.Services
import Pages.Org_.Repo_.Deployments
import Pages.Org_.Repo_.Deployments.Add
import Pages.Org_.Repo_.Hooks
import Pages.Org_.Repo_.Schedules
import Pages.Org_.Repo_.Schedules.Add
import Pages.Org_.Repo_.Schedules.Name_
import Pages.Org_.Repo_.Settings
import Pages.Secrets.Engine_.Org.Org_
import Pages.Secrets.Engine_.Org.Org_.Add
import Pages.Secrets.Engine_.Org.Org_.Name_
import Pages.Secrets.Engine_.Repo.Org_.Repo_
import Pages.Secrets.Engine_.Repo.Org_.Repo_.Add
import Pages.Secrets.Engine_.Repo.Org_.Repo_.Name_
import Pages.Secrets.Engine_.Shared.Org_.Team_
import Pages.Secrets.Engine_.Shared.Org_.Team_.Add
import Pages.Secrets.Engine_.Shared.Org_.Team_.Name_
import Route exposing (Route)
import Route.Path
import Shared
import Task
import Url exposing (Url)
import View exposing (View)


main : Program Json.Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }



-- INIT


type alias Model =
    { key : Browser.Navigation.Key
    , url : Url
    , page : Main.Pages.Model.Model
    , shared : Shared.Model
    , layout : Maybe Main.Layouts.Model.Model
    }


init : Json.Decode.Value -> Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init json url key =
    let
        flagsResult : Result Json.Decode.Error Shared.Flags
        flagsResult =
            Json.Decode.decodeValue Shared.decoder json

        ( sharedModel, sharedEffect ) =
            Shared.init flagsResult (Route.fromUrl () url)

        { page, layout } =
            initPageAndLayout { key = key, url = url, shared = sharedModel, layout = Nothing }
    in
    ( { url = url
      , key = key
      , page = Tuple.first page
      , layout = layout |> Maybe.map Tuple.first
      , shared = sharedModel
      }
    , Cmd.batch
        [ Tuple.second page
        , layout |> Maybe.map Tuple.second |> Maybe.withDefault Cmd.none
        , fromSharedEffect { key = key, url = url, shared = sharedModel } sharedEffect
        ]
    )


initLayout : { key : Browser.Navigation.Key, url : Url, shared : Shared.Model, layout : Maybe Main.Layouts.Model.Model } -> Layouts.Layout Msg -> ( Main.Layouts.Model.Model, Cmd Msg )
initLayout model layout =
    case ( layout, model.layout ) of
        ( Layouts.Default props, Just (Main.Layouts.Model.Default existing) ) ->
            ( Main.Layouts.Model.Default existing
            , Cmd.none
            )

        ( Layouts.Default props, Just (Main.Layouts.Model.Default_Org existing) ) ->
            ( Main.Layouts.Model.Default { default = existing.default }
            , Cmd.none
            )

        ( Layouts.Default props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultLayout =
                    Layouts.Default.layout props model.shared route

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default { default = defaultLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
            )

        ( Layouts.Default_Org props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Org.layout props model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()
            in
            ( Main.Layouts.Model.Default_Org { default = existing.default, org = nestedLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Org nestedLayoutEffect)
            )

        ( Layouts.Default_Org props, Just (Main.Layouts.Model.Default_Org existing) ) ->
            ( Main.Layouts.Model.Default_Org existing
            , Cmd.none
            )

        ( Layouts.Default_Org props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Org.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultNestedLayout) model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Org { default = defaultLayoutModel, org = nestedLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Org nestedLayoutEffect)
                , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
                ]
            )

        ( Layouts.Default_Repo props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Repo.layout props model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()
            in
            ( Main.Layouts.Model.Default_Repo { default = existing.default, repo = nestedLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Repo nestedLayoutEffect)
            )

        ( Layouts.Default_Repo props, Just (Main.Layouts.Model.Default_Repo existing) ) ->
            ( Main.Layouts.Model.Default_Repo existing
            , Cmd.none
            )

        ( Layouts.Default_Repo props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Repo.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultNestedLayout) model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Repo { default = defaultLayoutModel, repo = nestedLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Repo nestedLayoutEffect)
                , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
                ]
            )

        ( Layouts.Default_Build props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Build.layout props model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()
            in
            ( Main.Layouts.Model.Default_Build { default = existing.default, repo = nestedLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Build nestedLayoutEffect)
            )

        ( Layouts.Default_Build props, Just (Main.Layouts.Model.Default_Build existing) ) ->
            ( Main.Layouts.Model.Default_Build existing
            , Cmd.none
            )

        ( Layouts.Default_Build props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Build.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultNestedLayout) model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Build { default = defaultLayoutModel, repo = nestedLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Build nestedLayoutEffect)
                , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
                ]
            )


initPageAndLayout :
    { key : Browser.Navigation.Key
    , url : Url
    , shared : Shared.Model
    , layout : Maybe Main.Layouts.Model.Model
    }
    ->
        { page : ( Main.Pages.Model.Model, Cmd Msg )
        , layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg )
        }
initPageAndLayout model =
    case Route.Path.fromUrl model.url of
        Route.Path.AccountLogin ->
            let
                page : Page.Page Pages.Account.Login.Model Pages.Account.Login.Msg
                page =
                    Pages.Account.Login.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.AccountLogin
                    (Effect.map Main.Pages.Msg.AccountLogin >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountLogin >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.AccountSettings ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Account.Settings.Model Pages.Account.Settings.Msg
                        page =
                            Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.AccountSettings
                            (Effect.map Main.Pages.Msg.AccountSettings >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSettings >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.AccountSourceRepos ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Account.SourceRepos.Model Pages.Account.SourceRepos.Msg
                        page =
                            Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.AccountSourceRepos
                            (Effect.map Main.Pages.Msg.AccountSourceRepos >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSourceRepos >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.AccountLogout ->
            -- todo: fix: this is firing twice
            -- once on initial logout, with 200
            -- then again on logout response, with 401
            { page =
                ( Main.Pages.Model.Redirecting_
                , Effect.logout
                    { from = Dict.get "from" (Route.fromUrl () model.url).query }
                    |> Effect.toCmd
                        { key = model.key
                        , url = model.url
                        , shared = model.shared
                        , fromSharedMsg = Shared
                        , batch = Batch
                        , toCmd = Task.succeed >> Task.perform identity
                        }
                )
            , layout = Nothing
            }

        Route.Path.AccountAuthenticate_ ->
            let
                route =
                    Route.fromUrl () model.url

                code =
                    Dict.get "code" route.query

                state =
                    Dict.get "state" route.query
            in
            { page =
                ( Main.Pages.Model.Redirecting_
                , Effect.finishAuthentication { code = code, state = state }
                    |> Effect.toCmd { key = model.key, url = model.url, shared = model.shared, fromSharedMsg = Shared, batch = Batch, toCmd = Task.succeed >> Task.perform identity }
                )
            , layout = Nothing
            }

        Route.Path.Home ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Home.Model Pages.Home.Msg
                        page =
                            Pages.Home.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Home
                            (Effect.map Main.Pages.Msg.Home >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Home >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Model Pages.Org_.Msg
                        page =
                            Pages.Org_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_ params)
                            (Effect.map Main.Pages.Msg.Org_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Builds params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Builds.Model Pages.Org_.Builds.Msg
                        page =
                            Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Builds params)
                            (Effect.map Main.Pages.Msg.Org_Builds >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Builds >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Model Pages.Org_.Repo_.Msg
                        page =
                            Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_ params)
                            (Effect.map Main.Pages.Msg.Org_Repo_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Pulls params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Model Pages.Org_.Repo_.Msg
                        page =
                            Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_ params)
                            (Effect.map Main.Pages.Msg.Org_Repo_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Tags params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Model Pages.Org_.Repo_.Msg
                        page =
                            Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_ params)
                            (Effect.map Main.Pages.Msg.Org_Repo_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Deployments params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Deployments.Model Pages.Org_.Repo_.Deployments.Msg
                        page =
                            Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Deployments params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Deployments >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Deployments >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_DeploymentsAdd params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Deployments.Add.Model Pages.Org_.Repo_.Deployments.Add.Msg
                        page =
                            Pages.Org_.Repo_.Deployments.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_DeploymentsAdd params)
                            (Effect.map Main.Pages.Msg.Org_Repo_DeploymentsAdd >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_DeploymentsAdd >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Schedules params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Schedules.Model Pages.Org_.Repo_.Schedules.Msg
                        page =
                            Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Schedules params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Schedules >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Schedules >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_SchedulesAdd params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Schedules.Add.Model Pages.Org_.Repo_.Schedules.Add.Msg
                        page =
                            Pages.Org_.Repo_.Schedules.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_SchedulesAdd params)
                            (Effect.map Main.Pages.Msg.Org_Repo_SchedulesAdd >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_SchedulesAdd >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_SchedulesName_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Schedules.Name_.Model Pages.Org_.Repo_.Schedules.Name_.Msg
                        page =
                            Pages.Org_.Repo_.Schedules.Name_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_SchedulesName_ params)
                            (Effect.map Main.Pages.Msg.Org_Repo_SchedulesName_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_SchedulesName_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Hooks params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Hooks.Model Pages.Org_.Repo_.Hooks.Msg
                        page =
                            Pages.Org_.Repo_.Hooks.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Hooks params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Hooks >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Hooks >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Settings params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Settings.Model Pages.Org_.Repo_.Settings.Msg
                        page =
                            Pages.Org_.Repo_.Settings.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Settings params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Settings >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Settings >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Build_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Build_.Model Pages.Org_.Repo_.Build_.Msg
                        page =
                            Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Build_ params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Build_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Build_Services params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Build_.Services.Model Pages.Org_.Repo_.Build_.Services.Msg
                        page =
                            Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Build_Services params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Build_Services >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_Services >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Build_Pipeline params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Build_.Pipeline.Model Pages.Org_.Repo_.Build_.Pipeline.Msg
                        page =
                            Pages.Org_.Repo_.Build_.Pipeline.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Build_Pipeline params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Build_Pipeline >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_Pipeline >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Build_Graph params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Build_.Graph.Model Pages.Org_.Repo_.Build_.Graph.Msg
                        page =
                            Pages.Org_.Repo_.Build_.Graph.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Build_Graph params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Build_Graph >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_Graph >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.SecretsEngine_OrgOrg_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Secrets.Engine_.Org.Org_.Model Pages.Secrets.Engine_.Org.Org_.Msg
                        page =
                            Pages.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.SecretsEngine_OrgOrg_ params)
                            (Effect.map Main.Pages.Msg.SecretsEngine_OrgOrg_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_OrgOrg_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.SecretsEngine_OrgOrg_Add params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Secrets.Engine_.Org.Org_.Add.Model Pages.Secrets.Engine_.Org.Org_.Add.Msg
                        page =
                            Pages.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.SecretsEngine_OrgOrg_Add params)
                            (Effect.map Main.Pages.Msg.SecretsEngine_OrgOrg_Add >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_OrgOrg_Add >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.SecretsEngine_OrgOrg_Name_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Secrets.Engine_.Org.Org_.Name_.Model Pages.Secrets.Engine_.Org.Org_.Name_.Msg
                        page =
                            Pages.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.SecretsEngine_OrgOrg_Name_ params)
                            (Effect.map Main.Pages.Msg.SecretsEngine_OrgOrg_Name_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_OrgOrg_Name_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.SecretsEngine_RepoOrg_Repo_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Secrets.Engine_.Repo.Org_.Repo_.Model Pages.Secrets.Engine_.Repo.Org_.Repo_.Msg
                        page =
                            Pages.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.SecretsEngine_RepoOrg_Repo_ params)
                            (Effect.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.SecretsEngine_RepoOrg_Repo_Add params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.Model Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.Msg
                        page =
                            Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Add params)
                            (Effect.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Add >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Add >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.SecretsEngine_RepoOrg_Repo_Name_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Secrets.Engine_.Repo.Org_.Repo_.Name_.Model Pages.Secrets.Engine_.Repo.Org_.Repo_.Name_.Msg
                        page =
                            Pages.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Name_ params)
                            (Effect.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Name_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Name_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.SecretsEngine_SharedOrg_Team_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Secrets.Engine_.Shared.Org_.Team_.Model Pages.Secrets.Engine_.Shared.Org_.Team_.Msg
                        page =
                            Pages.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.SecretsEngine_SharedOrg_Team_ params)
                            (Effect.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_SharedOrg_Team_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.SecretsEngine_SharedOrg_Team_Add params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Secrets.Engine_.Shared.Org_.Team_.Add.Model Pages.Secrets.Engine_.Shared.Org_.Team_.Add.Msg
                        page =
                            Pages.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.SecretsEngine_SharedOrg_Team_Add params)
                            (Effect.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Add >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Add >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.SecretsEngine_SharedOrg_Team_Name_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Secrets.Engine_.Shared.Org_.Team_.Name_.Model Pages.Secrets.Engine_.Shared.Org_.Team_.Name_.Msg
                        page =
                            Pages.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.SecretsEngine_SharedOrg_Team_Name_ params)
                            (Effect.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Name_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Name_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.NotFound_ ->
            let
                page : Page.Page Pages.NotFound_.Model Pages.NotFound_.Msg
                page =
                    Pages.NotFound_.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.NotFound_
                    (Effect.map Main.Pages.Msg.NotFound_ >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.NotFound_ >> Page))
                    |> Maybe.map (initLayout model)
            }


runWhenAuthenticated : { model | shared : Shared.Model, url : Url, key : Browser.Navigation.Key } -> (Auth.User -> ( Main.Pages.Model.Model, Cmd Msg )) -> ( Main.Pages.Model.Model, Cmd Msg )
runWhenAuthenticated model toTuple =
    let
        record =
            runWhenAuthenticatedWithLayout model (\user -> { page = toTuple user, layout = Nothing })
    in
    record.page


runWhenAuthenticatedWithLayout : { model | shared : Shared.Model, url : Url, key : Browser.Navigation.Key } -> (Auth.User -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }) -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }
runWhenAuthenticatedWithLayout model toRecord =
    let
        authAction : Auth.Action.Action Auth.User
        authAction =
            Auth.onPageLoad model.shared (Route.fromUrl () model.url)

        toCmd : Effect Msg -> Cmd Msg
        toCmd =
            Effect.toCmd
                { key = model.key
                , url = model.url
                , shared = model.shared
                , fromSharedMsg = Shared
                , batch = Batch
                , toCmd = Task.succeed >> Task.perform identity
                }
    in
    case authAction of
        Auth.Action.LoadPageWithUser user ->
            toRecord user

        Auth.Action.ShowLoadingPage loadingView ->
            { page =
                ( Main.Pages.Model.Loading_
                , Cmd.none
                )
            , layout = Nothing
            }

        Auth.Action.ReplaceRoute options ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Cmd.batch
                    [ toCmd (Effect.replaceRoute options)
                    , Maybe.Extra.unwrap Cmd.none
                        (\from -> Interop.setRedirect <| Json.Encode.string from)
                        (Dict.get "from" options.query)
                    ]
                )
            , layout = Nothing
            }

        Auth.Action.PushRoute options ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Cmd.batch
                    [ toCmd (Effect.pushRoute options)
                    , Maybe.Extra.unwrap Cmd.none
                        (\from -> Interop.setRedirect <| Json.Encode.string from)
                        (Dict.get "from" options.query)
                    ]
                )
            , layout = Nothing
            }

        Auth.Action.LoadExternalUrl externalUrl ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Browser.Navigation.load externalUrl
                )
            , layout = Nothing
            }



-- UPDATE


type Msg
    = NoOp
    | UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | Page Main.Pages.Msg.Msg
    | Layout Main.Layouts.Msg.Msg
    | Shared Shared.Msg
    | Batch (List Msg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        UrlRequested (Browser.Internal url) ->
            ( model
            , Browser.Navigation.pushUrl model.key (Url.toString url)
            )

        UrlRequested (Browser.External url) ->
            ( model
            , Browser.Navigation.load url
            )

        UrlChanged url ->
            if Route.Path.fromUrl url == Route.Path.fromUrl model.url then
                let
                    newModel : Model
                    newModel =
                        { model | url = url }
                in
                ( newModel
                , Cmd.batch
                    [ toPageUrlHookCmd newModel
                        { from = Route.fromUrl () model.url
                        , to = Route.fromUrl () newModel.url
                        }
                    , toLayoutUrlHookCmd model
                        newModel
                        { from = Route.fromUrl () model.url
                        , to = Route.fromUrl () newModel.url
                        }
                    ]
                )

            else
                let
                    { page, layout } =
                        initPageAndLayout { key = model.key, shared = model.shared, layout = model.layout, url = url }

                    ( pageModel, pageCmd ) =
                        page

                    ( layoutModel, layoutCmd ) =
                        case layout of
                            Just ( layoutModel_, layoutCmd_ ) ->
                                ( Just layoutModel_, layoutCmd_ )

                            Nothing ->
                                ( Nothing, Cmd.none )

                    newModel =
                        { model | url = url, page = pageModel, layout = layoutModel }
                in
                ( newModel
                , Cmd.batch
                    [ pageCmd
                    , layoutCmd
                    , toLayoutUrlHookCmd model
                        newModel
                        { from = Route.fromUrl () model.url
                        , to = Route.fromUrl () newModel.url
                        }
                    ]
                )

        Page pageMsg ->
            let
                ( pageModel, pageCmd ) =
                    updateFromPage pageMsg model
            in
            ( { model | page = pageModel }
            , pageCmd
            )

        Layout layoutMsg ->
            let
                ( layoutModel, layoutCmd ) =
                    updateFromLayout layoutMsg model
            in
            ( { model | layout = layoutModel }
            , layoutCmd
            )

        Shared sharedMsg ->
            let
                ( sharedModel, sharedEffect ) =
                    Shared.update (Route.fromUrl () model.url) sharedMsg model.shared

                ( oldAction, newAction ) =
                    ( Auth.onPageLoad model.shared (Route.fromUrl () model.url)
                    , Auth.onPageLoad sharedModel (Route.fromUrl () model.url)
                    )
            in
            if isAuthProtected (Route.fromUrl () model.url).path && hasActionTypeChanged oldAction newAction then
                let
                    { layout, page } =
                        initPageAndLayout { key = model.key, shared = sharedModel, url = model.url, layout = model.layout }

                    ( pageModel, pageCmd ) =
                        page

                    ( layoutModel, layoutCmd ) =
                        ( layout |> Maybe.map Tuple.first
                        , layout |> Maybe.map Tuple.second |> Maybe.withDefault Cmd.none
                        )
                in
                ( { model | shared = sharedModel, page = pageModel, layout = layoutModel }
                , Cmd.batch
                    [ pageCmd
                    , layoutCmd
                    , fromSharedEffect { model | shared = sharedModel } sharedEffect
                    ]
                )

            else
                ( { model | shared = sharedModel }
                , fromSharedEffect { model | shared = sharedModel } sharedEffect
                )

        Batch messages ->
            ( model
            , messages
                |> List.map (Task.succeed >> Task.perform identity)
                |> Cmd.batch
            )


updateFromPage : Main.Pages.Msg.Msg -> Model -> ( Main.Pages.Model.Model, Cmd Msg )
updateFromPage msg model =
    case ( msg, model.page ) of
        ( Main.Pages.Msg.AccountLogin pageMsg, Main.Pages.Model.AccountLogin pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.AccountLogin
                (Effect.map Main.Pages.Msg.AccountLogin >> fromPageEffect model)
                (Page.update (Pages.Account.Login.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.AccountSettings pageMsg, Main.Pages.Model.AccountSettings pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.AccountSettings
                        (Effect.map Main.Pages.Msg.AccountSettings >> fromPageEffect model)
                        (Page.update (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.AccountSourceRepos pageMsg, Main.Pages.Model.AccountSourceRepos pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.AccountSourceRepos
                        (Effect.map Main.Pages.Msg.AccountSourceRepos >> fromPageEffect model)
                        (Page.update (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Home pageMsg, Main.Pages.Model.Home pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Home
                        (Effect.map Main.Pages.Msg.Home >> fromPageEffect model)
                        (Page.update (Pages.Home.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_ pageMsg, Main.Pages.Model.Org_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_ params)
                        (Effect.map Main.Pages.Msg.Org_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Builds pageMsg, Main.Pages.Model.Org_Builds params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Builds params)
                        (Effect.map Main.Pages.Msg.Org_Builds >> fromPageEffect model)
                        (Page.update (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_ pageMsg, Main.Pages.Model.Org_Repo_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_ params)
                        (Effect.map Main.Pages.Msg.Org_Repo_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Deployments pageMsg, Main.Pages.Model.Org_Repo_Deployments params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Deployments params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Deployments >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_DeploymentsAdd pageMsg, Main.Pages.Model.Org_Repo_DeploymentsAdd params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_DeploymentsAdd params)
                        (Effect.map Main.Pages.Msg.Org_Repo_DeploymentsAdd >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Deployments.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Schedules pageMsg, Main.Pages.Model.Org_Repo_Schedules params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Schedules params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Schedules >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_SchedulesAdd pageMsg, Main.Pages.Model.Org_Repo_SchedulesAdd params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_SchedulesAdd params)
                        (Effect.map Main.Pages.Msg.Org_Repo_SchedulesAdd >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Schedules.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_SchedulesName_ pageMsg, Main.Pages.Model.Org_Repo_SchedulesName_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_SchedulesName_ params)
                        (Effect.map Main.Pages.Msg.Org_Repo_SchedulesName_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Schedules.Name_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Hooks pageMsg, Main.Pages.Model.Org_Repo_Hooks params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Hooks params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Hooks >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Hooks.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Settings pageMsg, Main.Pages.Model.Org_Repo_Settings params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Settings params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Settings >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Settings.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Build_ pageMsg, Main.Pages.Model.Org_Repo_Build_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Build_ params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Build_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Build_Services pageMsg, Main.Pages.Model.Org_Repo_Build_Services params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Build_Services params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Build_Services >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Build_Pipeline pageMsg, Main.Pages.Model.Org_Repo_Build_Pipeline params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Build_Pipeline params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Build_Pipeline >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.Pipeline.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Build_Graph pageMsg, Main.Pages.Model.Org_Repo_Build_Graph params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Build_Graph params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Build_Graph >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.Graph.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.SecretsEngine_OrgOrg_ pageMsg, Main.Pages.Model.SecretsEngine_OrgOrg_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.SecretsEngine_OrgOrg_ params)
                        (Effect.map Main.Pages.Msg.SecretsEngine_OrgOrg_ >> fromPageEffect model)
                        (Page.update (Pages.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.SecretsEngine_OrgOrg_Add pageMsg, Main.Pages.Model.SecretsEngine_OrgOrg_Add params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.SecretsEngine_OrgOrg_Add params)
                        (Effect.map Main.Pages.Msg.SecretsEngine_OrgOrg_Add >> fromPageEffect model)
                        (Page.update (Pages.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.SecretsEngine_OrgOrg_Name_ pageMsg, Main.Pages.Model.SecretsEngine_OrgOrg_Name_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.SecretsEngine_OrgOrg_Name_ params)
                        (Effect.map Main.Pages.Msg.SecretsEngine_OrgOrg_Name_ >> fromPageEffect model)
                        (Page.update (Pages.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_ pageMsg, Main.Pages.Model.SecretsEngine_RepoOrg_Repo_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.SecretsEngine_RepoOrg_Repo_ params)
                        (Effect.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_ >> fromPageEffect model)
                        (Page.update (Pages.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Add pageMsg, Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Add params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Add params)
                        (Effect.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Add >> fromPageEffect model)
                        (Page.update (Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Name_ pageMsg, Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Name_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Name_ params)
                        (Effect.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Name_ >> fromPageEffect model)
                        (Page.update (Pages.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.SecretsEngine_SharedOrg_Team_ pageMsg, Main.Pages.Model.SecretsEngine_SharedOrg_Team_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.SecretsEngine_SharedOrg_Team_ params)
                        (Effect.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_ >> fromPageEffect model)
                        (Page.update (Pages.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Add pageMsg, Main.Pages.Model.SecretsEngine_SharedOrg_Team_Add params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.SecretsEngine_SharedOrg_Team_Add params)
                        (Effect.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Add >> fromPageEffect model)
                        (Page.update (Pages.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Name_ pageMsg, Main.Pages.Model.SecretsEngine_SharedOrg_Team_Name_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.SecretsEngine_SharedOrg_Team_Name_ params)
                        (Effect.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Name_ >> fromPageEffect model)
                        (Page.update (Pages.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.NotFound_ pageMsg, Main.Pages.Model.NotFound_ pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.NotFound_
                (Effect.map Main.Pages.Msg.NotFound_ >> fromPageEffect model)
                (Page.update (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        -- when you add a new page, remember to fill in this case
        _ ->
            ( model.page
            , Cmd.none
            )


updateFromLayout : Main.Layouts.Msg.Msg -> Model -> ( Maybe Main.Layouts.Model.Model, Cmd Msg )
updateFromLayout msg model =
    let
        route : Route ()
        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout, msg ) of
        ( Just (Layouts.Default props), Just (Main.Layouts.Model.Default layoutModel), Main.Layouts.Msg.Default layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default { layoutModel | default = newModel }))
                (Effect.map Main.Layouts.Msg.Default >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.layout props model.shared route) layoutMsg layoutModel.default)

        ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel), Main.Layouts.Msg.Default layoutMsg ) ->
            let
                defaultProps =
                    Layouts.Default.Org.layout props model.shared route
                        |> Layout.parentProps
            in
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Org { layoutModel | default = newModel }))
                (Effect.map Main.Layouts.Msg.Default >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.layout defaultProps model.shared route) layoutMsg layoutModel.default)

        ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel), Main.Layouts.Msg.Default_Org layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Org { layoutModel | org = newModel }))
                (Effect.map Main.Layouts.Msg.Default_Org >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.Org.layout props model.shared route) layoutMsg layoutModel.org)

        ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel), Main.Layouts.Msg.Default layoutMsg ) ->
            let
                defaultProps =
                    Layouts.Default.Repo.layout props model.shared route
                        |> Layout.parentProps
            in
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Repo { layoutModel | default = newModel }))
                (Effect.map Main.Layouts.Msg.Default >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.layout defaultProps model.shared route) layoutMsg layoutModel.default)

        ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel), Main.Layouts.Msg.Default_Repo layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Repo { layoutModel | repo = newModel }))
                (Effect.map Main.Layouts.Msg.Default_Repo >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.Repo.layout props model.shared route) layoutMsg layoutModel.repo)

        ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel), Main.Layouts.Msg.Default layoutMsg ) ->
            let
                defaultProps =
                    Layouts.Default.Build.layout props model.shared route
                        |> Layout.parentProps
            in
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Build { layoutModel | default = newModel }))
                (Effect.map Main.Layouts.Msg.Default >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.layout defaultProps model.shared route) layoutMsg layoutModel.default)

        ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel), Main.Layouts.Msg.Default_Build layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Build { layoutModel | repo = newModel }))
                (Effect.map Main.Layouts.Msg.Default_Build >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.Build.layout props model.shared route) layoutMsg layoutModel.repo)

        _ ->
            ( model.layout
            , Cmd.none
            )


toLayoutFromPage : Model -> Maybe (Layouts.Layout Msg)
toLayoutFromPage model =
    case model.page of
        Main.Pages.Model.AccountLogin pageModel ->
            Route.fromUrl () model.url
                |> Pages.Account.Login.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountLogin >> Page))

        Main.Pages.Model.AccountSettings pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Account.Settings.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSettings >> Page))

        Main.Pages.Model.AccountSourceRepos pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Account.SourceRepos.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSourceRepos >> Page))

        Main.Pages.Model.Home pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Home.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Home >> Page))

        Main.Pages.Model.Org_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_ >> Page))

        Main.Pages.Model.Org_Builds params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Builds.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Builds >> Page))

        Main.Pages.Model.Org_Repo_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_ >> Page))

        Main.Pages.Model.Org_Repo_Deployments params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Deployments.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Deployments >> Page))

        Main.Pages.Model.Org_Repo_DeploymentsAdd params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Deployments.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_DeploymentsAdd >> Page))

        Main.Pages.Model.Org_Repo_Schedules params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Schedules.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Schedules >> Page))

        Main.Pages.Model.Org_Repo_SchedulesAdd params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Schedules.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_SchedulesAdd >> Page))

        Main.Pages.Model.Org_Repo_SchedulesName_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Schedules.Name_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_SchedulesName_ >> Page))

        Main.Pages.Model.Org_Repo_Hooks params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Hooks.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Hooks >> Page))

        Main.Pages.Model.Org_Repo_Settings params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Settings.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Settings >> Page))

        Main.Pages.Model.Org_Repo_Build_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_ >> Page))

        Main.Pages.Model.Org_Repo_Build_Services params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.Services.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_Services >> Page))

        Main.Pages.Model.Org_Repo_Build_Pipeline params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.Pipeline.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_Pipeline >> Page))

        Main.Pages.Model.Org_Repo_Build_Graph params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.Graph.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_Graph >> Page))

        Main.Pages.Model.SecretsEngine_OrgOrg_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Secrets.Engine_.Org.Org_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_OrgOrg_ >> Page))

        Main.Pages.Model.SecretsEngine_OrgOrg_Add params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Secrets.Engine_.Org.Org_.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_OrgOrg_Add >> Page))

        Main.Pages.Model.SecretsEngine_OrgOrg_Name_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Secrets.Engine_.Org.Org_.Name_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_OrgOrg_Name_ >> Page))

        Main.Pages.Model.SecretsEngine_RepoOrg_Repo_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Secrets.Engine_.Repo.Org_.Repo_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_ >> Page))

        Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Add params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Add >> Page))

        Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Name_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Secrets.Engine_.Repo.Org_.Repo_.Name_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Name_ >> Page))

        Main.Pages.Model.SecretsEngine_SharedOrg_Team_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Secrets.Engine_.Shared.Org_.Team_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_SharedOrg_Team_ >> Page))

        Main.Pages.Model.SecretsEngine_SharedOrg_Team_Add params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Secrets.Engine_.Shared.Org_.Team_.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Add >> Page))

        Main.Pages.Model.SecretsEngine_SharedOrg_Team_Name_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Secrets.Engine_.Shared.Org_.Team_.Name_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Name_ >> Page))

        Main.Pages.Model.NotFound_ pageModel ->
            Route.fromUrl () model.url
                |> Pages.NotFound_.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.NotFound_ >> Page))

        Main.Pages.Model.Redirecting_ ->
            Nothing

        Main.Pages.Model.Loading_ ->
            Nothing


toAuthProtectedPage : Model -> (Auth.User -> Shared.Model -> Route params -> Page.Page model msg) -> Route params -> Maybe (Page.Page model msg)
toAuthProtectedPage model toPage route =
    case Auth.onPageLoad model.shared (Route.fromUrl () model.url) of
        Auth.Action.LoadPageWithUser user ->
            Just (toPage user model.shared route)

        _ ->
            Nothing


hasActionTypeChanged : Auth.Action.Action user -> Auth.Action.Action user -> Bool
hasActionTypeChanged oldAction newAction =
    case ( newAction, oldAction ) of
        ( Auth.Action.LoadPageWithUser _, Auth.Action.LoadPageWithUser _ ) ->
            False

        ( Auth.Action.ShowLoadingPage _, Auth.Action.ShowLoadingPage _ ) ->
            False

        ( Auth.Action.ReplaceRoute _, Auth.Action.ReplaceRoute _ ) ->
            False

        ( Auth.Action.PushRoute _, Auth.Action.PushRoute _ ) ->
            False

        ( Auth.Action.LoadExternalUrl _, Auth.Action.LoadExternalUrl _ ) ->
            False

        ( _, _ ) ->
            True


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        subscriptionsFromPage : Sub Msg
        subscriptionsFromPage =
            case model.page of
                Main.Pages.Model.AccountLogin pageModel ->
                    Page.subscriptions (Pages.Account.Login.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.AccountLogin
                        |> Sub.map Page

                Main.Pages.Model.AccountSettings pageModel ->
                    Sub.none

                Main.Pages.Model.AccountSourceRepos pageModel ->
                    Sub.none

                Main.Pages.Model.Home pageModel ->
                    Sub.none

                Main.Pages.Model.Org_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Builds params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Builds
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Deployments params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Deployments
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_DeploymentsAdd params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Deployments.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_DeploymentsAdd
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Schedules params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Schedules
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_SchedulesAdd params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Schedules.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_SchedulesAdd
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_SchedulesName_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Schedules.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_SchedulesName_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Hooks params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Hooks.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Hooks
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Settings params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Settings.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Settings
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Build_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Build_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Build_Services params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Build_Services
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Build_Pipeline params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.Pipeline.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Build_Pipeline
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Build_Graph params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.Graph.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Build_Graph
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.SecretsEngine_OrgOrg_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.SecretsEngine_OrgOrg_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.SecretsEngine_OrgOrg_Add params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.SecretsEngine_OrgOrg_Add
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.SecretsEngine_OrgOrg_Name_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.SecretsEngine_OrgOrg_Name_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.SecretsEngine_RepoOrg_Repo_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Add params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Add
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Name_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Name_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.SecretsEngine_SharedOrg_Team_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.SecretsEngine_SharedOrg_Team_Add params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Add
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.SecretsEngine_SharedOrg_Team_Name_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Name_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.NotFound_ pageModel ->
                    Page.subscriptions (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.NotFound_
                        |> Sub.map Page

                Main.Pages.Model.Redirecting_ ->
                    Sub.none

                Main.Pages.Model.Loading_ ->
                    Sub.none

        maybeLayout : Maybe (Layouts.Layout Msg)
        maybeLayout =
            toLayoutFromPage model

        route : Route ()
        route =
            Route.fromUrl () model.url

        subscriptionsFromLayout : Sub Msg
        subscriptionsFromLayout =
            case ( maybeLayout, model.layout ) of
                ( Just (Layouts.Default props), Just (Main.Layouts.Model.Default layoutModel) ) ->
                    Layout.subscriptions (Layouts.Default.layout props model.shared route) layoutModel.default
                        |> Sub.map Main.Layouts.Msg.Default
                        |> Sub.map Layout

                ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel) ) ->
                    let
                        defaultProps =
                            Layouts.Default.Org.layout props model.shared route
                                |> Layout.parentProps
                    in
                    Sub.batch
                        [ Layout.subscriptions (Layouts.Default.layout defaultProps model.shared route) layoutModel.default
                            |> Sub.map Main.Layouts.Msg.Default
                            |> Sub.map Layout
                        , Layout.subscriptions (Layouts.Default.Org.layout props model.shared route) layoutModel.org
                            |> Sub.map Main.Layouts.Msg.Default_Org
                            |> Sub.map Layout
                        ]

                ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel) ) ->
                    let
                        defaultProps =
                            Layouts.Default.Repo.layout props model.shared route
                                |> Layout.parentProps
                    in
                    Sub.batch
                        [ Layout.subscriptions (Layouts.Default.layout defaultProps model.shared route) layoutModel.default
                            |> Sub.map Main.Layouts.Msg.Default
                            |> Sub.map Layout
                        , Layout.subscriptions (Layouts.Default.Repo.layout props model.shared route) layoutModel.repo
                            |> Sub.map Main.Layouts.Msg.Default_Repo
                            |> Sub.map Layout
                        ]

                ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel) ) ->
                    let
                        defaultProps =
                            Layouts.Default.Build.layout props model.shared route
                                |> Layout.parentProps
                    in
                    Sub.batch
                        [ Layout.subscriptions (Layouts.Default.layout defaultProps model.shared route) layoutModel.default
                            |> Sub.map Main.Layouts.Msg.Default
                            |> Sub.map Layout
                        , Layout.subscriptions (Layouts.Default.Build.layout props model.shared route) layoutModel.repo
                            |> Sub.map Main.Layouts.Msg.Default_Build
                            |> Sub.map Layout
                        ]

                _ ->
                    Sub.none
    in
    Sub.batch
        [ Shared.subscriptions route model.shared
            |> Sub.map Shared
        , subscriptionsFromPage
        , subscriptionsFromLayout
        ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        view_ : View Msg
        view_ =
            toView model
    in
    View.toBrowserDocument
        { shared = model.shared
        , route = Route.fromUrl () model.url
        , view = view_
        }


toView : Model -> View Msg
toView model =
    let
        route : Route ()
        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout ) of
        ( Just (Layouts.Default props), Just (Main.Layouts.Model.Default layoutModel) ) ->
            Layout.view
                (Layouts.Default.layout props model.shared route)
                { model = layoutModel.default
                , toContentMsg = Main.Layouts.Msg.Default >> Layout
                , content = viewPage model
                }

        ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Org.layout props model.shared route
                        |> Layout.parentProps
            in
            Layout.view
                (Layouts.Default.layout defaultProps model.shared route)
                { model = layoutModel.default
                , toContentMsg = Main.Layouts.Msg.Default >> Layout
                , content =
                    Layout.view
                        (Layouts.Default.Org.layout props model.shared route)
                        { model = layoutModel.org
                        , toContentMsg = Main.Layouts.Msg.Default_Org >> Layout
                        , content = viewPage model
                        }
                }

        ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Repo.layout props model.shared route
                        |> Layout.parentProps
            in
            Layout.view
                (Layouts.Default.layout defaultProps model.shared route)
                { model = layoutModel.default
                , toContentMsg = Main.Layouts.Msg.Default >> Layout
                , content =
                    Layout.view
                        (Layouts.Default.Repo.layout props model.shared route)
                        { model = layoutModel.repo
                        , toContentMsg = Main.Layouts.Msg.Default_Repo >> Layout
                        , content = viewPage model
                        }
                }

        ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Build.layout props model.shared route
                        |> Layout.parentProps
            in
            Layout.view
                (Layouts.Default.layout defaultProps model.shared route)
                { model = layoutModel.default
                , toContentMsg = Main.Layouts.Msg.Default >> Layout
                , content =
                    Layout.view
                        (Layouts.Default.Build.layout props model.shared route)
                        { model = layoutModel.repo
                        , toContentMsg = Main.Layouts.Msg.Default_Build >> Layout
                        , content = viewPage model
                        }
                }

        _ ->
            viewPage model


viewPage : Model -> View Msg
viewPage model =
    case model.page of
        Main.Pages.Model.AccountLogin pageModel ->
            Page.view (Pages.Account.Login.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.AccountLogin
                |> View.map Page

        Main.Pages.Model.AccountSettings pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.AccountSettings
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.AccountSourceRepos pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.AccountSourceRepos
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Home pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Home.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Home
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Builds params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Builds
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Deployments params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Deployments
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_DeploymentsAdd params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Deployments.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_DeploymentsAdd
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Schedules params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Schedules
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_SchedulesAdd params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Schedules.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_SchedulesAdd
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_SchedulesName_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Schedules.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_SchedulesName_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Hooks params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Hooks.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Hooks
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Settings params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Settings.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Settings
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Build_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_Services params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Build_Services
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_Pipeline params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.Pipeline.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Build_Pipeline
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_Graph params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.Graph.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Build_Graph
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_OrgOrg_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.SecretsEngine_OrgOrg_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_OrgOrg_Add params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.SecretsEngine_OrgOrg_Add
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_OrgOrg_Name_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.SecretsEngine_OrgOrg_Name_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_RepoOrg_Repo_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Add params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Add
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Name_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Name_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_SharedOrg_Team_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_SharedOrg_Team_Add params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Add
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_SharedOrg_Team_Name_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Name_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.NotFound_ pageModel ->
            Page.view (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.NotFound_
                |> View.map Page

        Main.Pages.Model.Redirecting_ ->
            View.none

        Main.Pages.Model.Loading_ ->
            Auth.viewLoadingPage model.shared (Route.fromUrl () model.url)
                |> View.map never



-- INTERNALS


fromPageEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Main.Pages.Msg.Msg -> Cmd Msg
fromPageEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Page effect)


fromLayoutEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Main.Layouts.Msg.Msg -> Cmd Msg
fromLayoutEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Layout effect)


fromSharedEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Shared.Msg -> Cmd Msg
fromSharedEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Shared effect)



-- URL HOOKS FOR PAGES


toPageUrlHookCmd : Model -> { from : Route (), to : Route () } -> Cmd Msg
toPageUrlHookCmd model routes =
    let
        toCommands messages =
            messages
                |> List.map (Task.succeed >> Task.perform identity)
                |> Cmd.batch
    in
    case model.page of
        Main.Pages.Model.AccountLogin pageModel ->
            Page.toUrlMessages routes (Pages.Account.Login.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.AccountLogin
                |> List.map Page
                |> toCommands

        Main.Pages.Model.AccountSettings pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.AccountSettings
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.AccountSourceRepos pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.AccountSourceRepos
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Home pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Home.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Home
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Builds params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Builds
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Deployments params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Deployments
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_DeploymentsAdd params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Deployments.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_DeploymentsAdd
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Schedules params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Schedules
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_SchedulesAdd params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Schedules.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_SchedulesAdd
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_SchedulesName_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Schedules.Name_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_SchedulesName_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Hooks params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Hooks.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Hooks
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Settings params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Settings.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Settings
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_OrgOrg_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.SecretsEngine_OrgOrg_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Build_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_Services params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Build_Services
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_Pipeline params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.Pipeline.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Build_Pipeline
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_Graph params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.Graph.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Build_Graph
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.NotFound_ pageModel ->
            Page.toUrlMessages routes (Pages.NotFound_.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.NotFound_
                |> List.map Page
                |> toCommands

        Main.Pages.Model.SecretsEngine_OrgOrg_Add params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.SecretsEngine_OrgOrg_Add
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_OrgOrg_Name_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.SecretsEngine_OrgOrg_Name_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_RepoOrg_Repo_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Add params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Add
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_RepoOrg_Repo_Name_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.SecretsEngine_RepoOrg_Repo_Name_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_SharedOrg_Team_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_SharedOrg_Team_Add params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Add
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.SecretsEngine_SharedOrg_Team_Name_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.SecretsEngine_SharedOrg_Team_Name_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Redirecting_ ->
            Cmd.none

        Main.Pages.Model.Loading_ ->
            Cmd.none


toLayoutUrlHookCmd : Model -> Model -> { from : Route (), to : Route () } -> Cmd Msg
toLayoutUrlHookCmd oldModel model routes =
    let
        toCommands messages =
            if shouldFireUrlChangedEvents then
                messages
                    |> List.map (Task.succeed >> Task.perform identity)
                    |> Cmd.batch

            else
                Cmd.none

        shouldFireUrlChangedEvents =
            hasNavigatedWithinNewLayout
                { from = toLayoutFromPage oldModel
                , to = toLayoutFromPage model
                }

        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout ) of
        ( Just (Layouts.Default props), Just (Main.Layouts.Model.Default layoutModel) ) ->
            Layout.toUrlMessages routes (Layouts.Default.layout props model.shared route)
                |> List.map Main.Layouts.Msg.Default
                |> List.map Layout
                |> toCommands

        ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Org.layout props model.shared route
                        |> Layout.parentProps
            in
            Cmd.batch
                [ Layout.toUrlMessages routes (Layouts.Default.layout defaultProps model.shared route)
                    |> List.map Main.Layouts.Msg.Default
                    |> List.map Layout
                    |> toCommands
                , Layout.toUrlMessages routes (Layouts.Default.Org.layout props model.shared route)
                    |> List.map Main.Layouts.Msg.Default_Org
                    |> List.map Layout
                    |> toCommands
                ]

        ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Repo.layout props model.shared route
                        |> Layout.parentProps
            in
            Cmd.batch
                [ Layout.toUrlMessages routes (Layouts.Default.layout defaultProps model.shared route)
                    |> List.map Main.Layouts.Msg.Default
                    |> List.map Layout
                    |> toCommands
                , Layout.toUrlMessages routes (Layouts.Default.Repo.layout props model.shared route)
                    |> List.map Main.Layouts.Msg.Default_Repo
                    |> List.map Layout
                    |> toCommands
                ]

        ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Build.layout props model.shared route
                        |> Layout.parentProps
            in
            Cmd.batch
                [ Layout.toUrlMessages routes (Layouts.Default.layout defaultProps model.shared route)
                    |> List.map Main.Layouts.Msg.Default
                    |> List.map Layout
                    |> toCommands
                , Layout.toUrlMessages routes (Layouts.Default.Build.layout props model.shared route)
                    |> List.map Main.Layouts.Msg.Default_Build
                    |> List.map Layout
                    |> toCommands
                ]

        _ ->
            Cmd.none


hasNavigatedWithinNewLayout : { from : Maybe (Layouts.Layout msg), to : Maybe (Layouts.Layout msg) } -> Bool
hasNavigatedWithinNewLayout { from, to } =
    let
        isRelated maybePair =
            case maybePair of
                Just ( Layouts.Default _, Layouts.Default _ ) ->
                    True

                Just ( Layouts.Default_Org _, Layouts.Default_Org _ ) ->
                    True

                Just ( Layouts.Default_Org _, Layouts.Default _ ) ->
                    True

                Just ( Layouts.Default_Repo _, Layouts.Default_Repo _ ) ->
                    True

                Just ( Layouts.Default_Repo _, Layouts.Default _ ) ->
                    True

                Just ( Layouts.Default_Build _, Layouts.Default_Build _ ) ->
                    True

                Just ( Layouts.Default_Build _, Layouts.Default _ ) ->
                    True

                _ ->
                    False
    in
    List.any isRelated
        [ Maybe.map2 Tuple.pair from to
        , Maybe.map2 Tuple.pair to from
        ]


isAuthProtected : Route.Path.Path -> Bool
isAuthProtected routePath =
    case routePath of
        Route.Path.AccountLogin ->
            False

        Route.Path.AccountLogout ->
            True

        Route.Path.AccountAuthenticate_ ->
            False

        Route.Path.AccountSettings ->
            True

        Route.Path.AccountSourceRepos ->
            True

        Route.Path.Home ->
            True

        Route.Path.Org_ _ ->
            True

        Route.Path.Org_Builds _ ->
            True

        Route.Path.Org_Repo_ _ ->
            True

        Route.Path.Org_Repo_Pulls _ ->
            True

        Route.Path.Org_Repo_Tags _ ->
            True

        Route.Path.Org_Repo_Deployments _ ->
            True

        Route.Path.Org_Repo_DeploymentsAdd _ ->
            True

        Route.Path.Org_Repo_Schedules _ ->
            True

        Route.Path.Org_Repo_SchedulesAdd _ ->
            True

        Route.Path.Org_Repo_SchedulesName_ _ ->
            True

        Route.Path.Org_Repo_Hooks _ ->
            True

        Route.Path.Org_Repo_Settings _ ->
            True

        Route.Path.Org_Repo_Build_ _ ->
            True

        Route.Path.Org_Repo_Build_Services _ ->
            True

        Route.Path.Org_Repo_Build_Pipeline _ ->
            True

        Route.Path.Org_Repo_Build_Graph _ ->
            True

        Route.Path.SecretsEngine_OrgOrg_ _ ->
            True

        Route.Path.SecretsEngine_OrgOrg_Add _ ->
            True

        Route.Path.SecretsEngine_OrgOrg_Name_ _ ->
            True

        Route.Path.SecretsEngine_RepoOrg_Repo_ _ ->
            True

        Route.Path.SecretsEngine_RepoOrg_Repo_Add _ ->
            True

        Route.Path.SecretsEngine_RepoOrg_Repo_Name_ _ ->
            True

        Route.Path.SecretsEngine_SharedOrg_Team_ _ ->
            True

        Route.Path.SecretsEngine_SharedOrg_Team_Add _ ->
            True

        Route.Path.SecretsEngine_SharedOrg_Team_Name_ _ ->
            True

        Route.Path.NotFound_ ->
            False
