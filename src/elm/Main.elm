{--
SPDX-License-Identifier: Apache-2.0
--}


module Main exposing (..)

import Auth
import Auth.Action
import Browser
import Browser.Navigation
import Dict
import Effect exposing (Effect)
import Html exposing (Html)
import Interop
import Json.Decode
import Json.Encode
import Layout
import Layouts
import Layouts.Default
import Layouts.Default.Admin
import Layouts.Default.Build
import Layouts.Default.Org
import Layouts.Default.Repo
import Main.Layouts.Model
import Main.Layouts.Msg
import Main.Pages.Model
import Main.Pages.Msg
import Maybe.Extra
import Page
import Pages.Account.Authenticate
import Pages.Account.Login
import Pages.Account.Logout
import Pages.Account.Settings
import Pages.Account.SourceRepos
import Pages.Admin.Settings
import Pages.Dash.Secrets.Engine_.Org.Org_
import Pages.Dash.Secrets.Engine_.Org.Org_.Add
import Pages.Dash.Secrets.Engine_.Org.Org_.Name_
import Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_
import Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add
import Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_
import Pages.Dash.Secrets.Engine_.Shared.Org_.Team_
import Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add
import Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_
import Pages.Dashboards
import Pages.Dashboards.Dashboard_
import Pages.Home_
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
import Pages.Org_.Repo_.Insights
import Pages.Org_.Repo_.Pulls
import Pages.Org_.Repo_.Schedules
import Pages.Org_.Repo_.Schedules.Add
import Pages.Org_.Repo_.Schedules.Name_
import Pages.Org_.Repo_.Settings
import Pages.Org_.Repo_.Tags
import Pages.Status.Workers
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
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }



-- INIT


type alias Model =
    { key : Browser.Navigation.Key
    , url : Url
    , page : Main.Pages.Model.Model
    , layout : Maybe Main.Layouts.Model.Model
    , shared : Shared.Model
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

        ( Layouts.Default props, Just (Main.Layouts.Model.Default_Admin existing) ) ->
            ( Main.Layouts.Model.Default { default = existing.default }
            , Cmd.none
            )

        ( Layouts.Default props, Just (Main.Layouts.Model.Default_Build existing) ) ->
            ( Main.Layouts.Model.Default { default = existing.default }
            , Cmd.none
            )

        ( Layouts.Default props, Just (Main.Layouts.Model.Default_Org existing) ) ->
            ( Main.Layouts.Model.Default { default = existing.default }
            , Cmd.none
            )

        ( Layouts.Default props, Just (Main.Layouts.Model.Default_Repo existing) ) ->
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

        ( Layouts.Default_Admin props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultAdminLayout =
                    Layouts.Default.Admin.layout props model.shared route

                ( adminLayoutModel, adminLayoutEffect ) =
                    Layout.init defaultAdminLayout ()
            in
            ( Main.Layouts.Model.Default_Admin { default = existing.default, admin = adminLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Admin adminLayoutEffect)
            )

        ( Layouts.Default_Admin props, Just (Main.Layouts.Model.Default_Admin existing) ) ->
            ( Main.Layouts.Model.Default_Admin existing
            , Cmd.none
            )

        ( Layouts.Default_Admin props, Just (Main.Layouts.Model.Default_Build existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultAdminLayout =
                    Layouts.Default.Admin.layout props model.shared route

                ( adminLayoutModel, adminLayoutEffect ) =
                    Layout.init defaultAdminLayout ()
            in
            ( Main.Layouts.Model.Default_Admin { default = existing.default, admin = adminLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Admin adminLayoutEffect)
            )

        ( Layouts.Default_Admin props, Just (Main.Layouts.Model.Default_Org existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultAdminLayout =
                    Layouts.Default.Admin.layout props model.shared route

                ( adminLayoutModel, adminLayoutEffect ) =
                    Layout.init defaultAdminLayout ()
            in
            ( Main.Layouts.Model.Default_Admin { default = existing.default, admin = adminLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Admin adminLayoutEffect)
            )

        ( Layouts.Default_Admin props, Just (Main.Layouts.Model.Default_Repo existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultAdminLayout =
                    Layouts.Default.Admin.layout props model.shared route

                ( adminLayoutModel, adminLayoutEffect ) =
                    Layout.init defaultAdminLayout ()
            in
            ( Main.Layouts.Model.Default_Admin { default = existing.default, admin = adminLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Admin adminLayoutEffect)
            )

        ( Layouts.Default_Admin props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultAdminLayout =
                    Layouts.Default.Admin.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultAdminLayout) model.shared route

                ( adminLayoutModel, adminLayoutEffect ) =
                    Layout.init defaultAdminLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Admin { default = defaultLayoutModel, admin = adminLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Admin adminLayoutEffect)
                , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
                ]
            )

        ( Layouts.Default_Build props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultBuildLayout =
                    Layouts.Default.Build.layout props model.shared route

                ( buildLayoutModel, buildLayoutEffect ) =
                    Layout.init defaultBuildLayout ()
            in
            ( Main.Layouts.Model.Default_Build { default = existing.default, build = buildLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Build buildLayoutEffect)
            )

        ( Layouts.Default_Build props, Just (Main.Layouts.Model.Default_Admin existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultBuildLayout =
                    Layouts.Default.Build.layout props model.shared route

                ( buildLayoutModel, buildLayoutEffect ) =
                    Layout.init defaultBuildLayout ()
            in
            ( Main.Layouts.Model.Default_Build { default = existing.default, build = buildLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Build buildLayoutEffect)
            )

        ( Layouts.Default_Build props, Just (Main.Layouts.Model.Default_Build existing) ) ->
            ( Main.Layouts.Model.Default_Build existing
            , Cmd.none
            )

        ( Layouts.Default_Build props, Just (Main.Layouts.Model.Default_Org existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultBuildLayout =
                    Layouts.Default.Build.layout props model.shared route

                ( buildLayoutModel, buildLayoutEffect ) =
                    Layout.init defaultBuildLayout ()
            in
            ( Main.Layouts.Model.Default_Build { default = existing.default, build = buildLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Build buildLayoutEffect)
            )

        ( Layouts.Default_Build props, Just (Main.Layouts.Model.Default_Repo existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultBuildLayout =
                    Layouts.Default.Build.layout props model.shared route

                ( buildLayoutModel, buildLayoutEffect ) =
                    Layout.init defaultBuildLayout ()
            in
            ( Main.Layouts.Model.Default_Build { default = existing.default, build = buildLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Build buildLayoutEffect)
            )

        ( Layouts.Default_Build props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultBuildLayout =
                    Layouts.Default.Build.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultBuildLayout) model.shared route

                ( buildLayoutModel, buildLayoutEffect ) =
                    Layout.init defaultBuildLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Build { default = defaultLayoutModel, build = buildLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Build buildLayoutEffect)
                , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
                ]
            )

        ( Layouts.Default_Org props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultOrgLayout =
                    Layouts.Default.Org.layout props model.shared route

                ( orgLayoutModel, orgLayoutEffect ) =
                    Layout.init defaultOrgLayout ()
            in
            ( Main.Layouts.Model.Default_Org { default = existing.default, org = orgLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Org orgLayoutEffect)
            )

        ( Layouts.Default_Org props, Just (Main.Layouts.Model.Default_Admin existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultOrgLayout =
                    Layouts.Default.Org.layout props model.shared route

                ( orgLayoutModel, orgLayoutEffect ) =
                    Layout.init defaultOrgLayout ()
            in
            ( Main.Layouts.Model.Default_Org { default = existing.default, org = orgLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Org orgLayoutEffect)
            )

        ( Layouts.Default_Org props, Just (Main.Layouts.Model.Default_Build existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultOrgLayout =
                    Layouts.Default.Org.layout props model.shared route

                ( orgLayoutModel, orgLayoutEffect ) =
                    Layout.init defaultOrgLayout ()
            in
            ( Main.Layouts.Model.Default_Org { default = existing.default, org = orgLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Org orgLayoutEffect)
            )

        ( Layouts.Default_Org props, Just (Main.Layouts.Model.Default_Org existing) ) ->
            ( Main.Layouts.Model.Default_Org existing
            , Cmd.none
            )

        ( Layouts.Default_Org props, Just (Main.Layouts.Model.Default_Repo existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultOrgLayout =
                    Layouts.Default.Org.layout props model.shared route

                ( orgLayoutModel, orgLayoutEffect ) =
                    Layout.init defaultOrgLayout ()
            in
            ( Main.Layouts.Model.Default_Org { default = existing.default, org = orgLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Org orgLayoutEffect)
            )

        ( Layouts.Default_Org props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultOrgLayout =
                    Layouts.Default.Org.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultOrgLayout) model.shared route

                ( orgLayoutModel, orgLayoutEffect ) =
                    Layout.init defaultOrgLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Org { default = defaultLayoutModel, org = orgLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Org orgLayoutEffect)
                , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
                ]
            )

        ( Layouts.Default_Repo props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultRepoLayout =
                    Layouts.Default.Repo.layout props model.shared route

                ( repoLayoutModel, repoLayoutEffect ) =
                    Layout.init defaultRepoLayout ()
            in
            ( Main.Layouts.Model.Default_Repo { default = existing.default, repo = repoLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Repo repoLayoutEffect)
            )

        ( Layouts.Default_Repo props, Just (Main.Layouts.Model.Default_Admin existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultRepoLayout =
                    Layouts.Default.Repo.layout props model.shared route

                ( repoLayoutModel, repoLayoutEffect ) =
                    Layout.init defaultRepoLayout ()
            in
            ( Main.Layouts.Model.Default_Repo { default = existing.default, repo = repoLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Repo repoLayoutEffect)
            )

        ( Layouts.Default_Repo props, Just (Main.Layouts.Model.Default_Build existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultRepoLayout =
                    Layouts.Default.Repo.layout props model.shared route

                ( repoLayoutModel, repoLayoutEffect ) =
                    Layout.init defaultRepoLayout ()
            in
            ( Main.Layouts.Model.Default_Repo { default = existing.default, repo = repoLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Repo repoLayoutEffect)
            )

        ( Layouts.Default_Repo props, Just (Main.Layouts.Model.Default_Org existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultRepoLayout =
                    Layouts.Default.Repo.layout props model.shared route

                ( repoLayoutModel, repoLayoutEffect ) =
                    Layout.init defaultRepoLayout ()
            in
            ( Main.Layouts.Model.Default_Repo { default = existing.default, repo = repoLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Repo repoLayoutEffect)
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

                defaultRepoLayout =
                    Layouts.Default.Repo.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultRepoLayout) model.shared route

                ( repoLayoutModel, repoLayoutEffect ) =
                    Layout.init defaultRepoLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Repo { default = defaultLayoutModel, repo = repoLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Repo repoLayoutEffect)
                , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
                ]
            )


initPageAndLayout : { key : Browser.Navigation.Key, url : Url, shared : Shared.Model, layout : Maybe Main.Layouts.Model.Model } -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }
initPageAndLayout model =
    case Route.Path.fromUrl model.url of
        Route.Path.Home_ ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Home_.Model Pages.Home_.Msg
                        page =
                            Pages.Home_.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Home_
                            (Effect.map Main.Pages.Msg.Home_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Home_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Account_Authenticate ->
            let
                page : Page.Page Pages.Account.Authenticate.Model Pages.Account.Authenticate.Msg
                page =
                    Pages.Account.Authenticate.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.Account_Authenticate
                    (Effect.map Main.Pages.Msg.Account_Authenticate >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_Authenticate >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.Account_Login ->
            let
                page : Page.Page Pages.Account.Login.Model Pages.Account.Login.Msg
                page =
                    Pages.Account.Login.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.Account_Login
                    (Effect.map Main.Pages.Msg.Account_Login >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_Login >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.Account_Logout ->
            let
                page : Page.Page Pages.Account.Logout.Model Pages.Account.Logout.Msg
                page =
                    Pages.Account.Logout.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.Account_Logout
                    (Effect.map Main.Pages.Msg.Account_Logout >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_Logout >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.Account_Settings ->
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
                            Main.Pages.Model.Account_Settings
                            (Effect.map Main.Pages.Msg.Account_Settings >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_Settings >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Account_SourceRepos ->
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
                            Main.Pages.Model.Account_SourceRepos
                            (Effect.map Main.Pages.Msg.Account_SourceRepos >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_SourceRepos >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Admin_Settings ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Admin.Settings.Model Pages.Admin.Settings.Msg
                        page =
                            Pages.Admin.Settings.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Admin_Settings
                            (Effect.map Main.Pages.Msg.Admin_Settings >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Admin_Settings >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dash_Secrets_Engine__Org_Org_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dash.Secrets.Engine_.Org.Org_.Model Pages.Dash.Secrets.Engine_.Org.Org_.Msg
                        page =
                            Pages.Dash.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dash_Secrets_Engine__Org_Org_ params)
                            (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Org_Org_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dash_Secrets_Engine__Org_Org__Add params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dash.Secrets.Engine_.Org.Org_.Add.Model Pages.Dash.Secrets.Engine_.Org.Org_.Add.Msg
                        page =
                            Pages.Dash.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Add params)
                            (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Add >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Add >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dash_Secrets_Engine__Org_Org__Name_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dash.Secrets.Engine_.Org.Org_.Name_.Model Pages.Dash.Secrets.Engine_.Org.Org_.Name_.Msg
                        page =
                            Pages.Dash.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Name_ params)
                            (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Name_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Name_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dash_Secrets_Engine__Repo_Org__Repo_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Model Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Msg
                        page =
                            Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo_ params)
                            (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dash_Secrets_Engine__Repo_Org__Repo__Add params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.Model Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.Msg
                        page =
                            Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Add params)
                            (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Add >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Add >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dash_Secrets_Engine__Repo_Org__Repo__Name_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.Model Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.Msg
                        page =
                            Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Name_ params)
                            (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Name_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Name_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dash_Secrets_Engine__Shared_Org__Team_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Model Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Msg
                        page =
                            Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team_ params)
                            (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dash_Secrets_Engine__Shared_Org__Team__Add params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.Model Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.Msg
                        page =
                            Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Add params)
                            (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Add >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Add >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dash_Secrets_Engine__Shared_Org__Team__Name_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.Model Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.Msg
                        page =
                            Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Name_ params)
                            (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Name_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Name_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dashboards ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dashboards.Model Pages.Dashboards.Msg
                        page =
                            Pages.Dashboards.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Dashboards
                            (Effect.map Main.Pages.Msg.Dashboards >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dashboards >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Dashboards_Dashboard_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Dashboards.Dashboard_.Model Pages.Dashboards.Dashboard_.Msg
                        page =
                            Pages.Dashboards.Dashboard_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Dashboards_Dashboard_ params)
                            (Effect.map Main.Pages.Msg.Dashboards_Dashboard_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Dashboards_Dashboard_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Status_Workers ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Status.Workers.Model Pages.Status.Workers.Msg
                        page =
                            Pages.Status.Workers.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Status_Workers
                            (Effect.map Main.Pages.Msg.Status_Workers >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Status_Workers >> Page))
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

        Route.Path.Org__Builds params ->
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
                            (Main.Pages.Model.Org__Builds params)
                            (Effect.map Main.Pages.Msg.Org__Builds >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Builds >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo_ params ->
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
                            (Main.Pages.Model.Org__Repo_ params)
                            (Effect.map Main.Pages.Msg.Org__Repo_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Deployments params ->
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
                            (Main.Pages.Model.Org__Repo__Deployments params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Deployments >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Deployments >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Deployments_Add params ->
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
                            (Main.Pages.Model.Org__Repo__Deployments_Add params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Deployments_Add >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Deployments_Add >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Hooks params ->
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
                            (Main.Pages.Model.Org__Repo__Hooks params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Hooks >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Hooks >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Insights params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Insights.Model Pages.Org_.Repo_.Insights.Msg
                        page =
                            Pages.Org_.Repo_.Insights.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org__Repo__Insights params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Insights >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Insights >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Pulls params ->
            let
                page : Page.Page Pages.Org_.Repo_.Pulls.Model Pages.Org_.Repo_.Pulls.Msg
                page =
                    Pages.Org_.Repo_.Pulls.page model.shared (Route.fromUrl params model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    (Main.Pages.Model.Org__Repo__Pulls params)
                    (Effect.map Main.Pages.Msg.Org__Repo__Pulls >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Pulls >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.Org__Repo__Schedules params ->
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
                            (Main.Pages.Model.Org__Repo__Schedules params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Schedules >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Schedules >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Schedules_Add params ->
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
                            (Main.Pages.Model.Org__Repo__Schedules_Add params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Schedules_Add >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Schedules_Add >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Schedules_Name_ params ->
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
                            (Main.Pages.Model.Org__Repo__Schedules_Name_ params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Schedules_Name_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Schedules_Name_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Settings params ->
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
                            (Main.Pages.Model.Org__Repo__Settings params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Settings >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Settings >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Tags params ->
            let
                page : Page.Page Pages.Org_.Repo_.Tags.Model Pages.Org_.Repo_.Tags.Msg
                page =
                    Pages.Org_.Repo_.Tags.page model.shared (Route.fromUrl params model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    (Main.Pages.Model.Org__Repo__Tags params)
                    (Effect.map Main.Pages.Msg.Org__Repo__Tags >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Tags >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.Org__Repo__Build_ params ->
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
                            (Main.Pages.Model.Org__Repo__Build_ params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Build_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Build_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Build__Graph params ->
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
                            (Main.Pages.Model.Org__Repo__Build__Graph params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Build__Graph >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Build__Graph >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Build__Pipeline params ->
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
                            (Main.Pages.Model.Org__Repo__Build__Pipeline params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Build__Pipeline >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Build__Pipeline >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org__Repo__Build__Services params ->
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
                            (Main.Pages.Model.Org__Repo__Build__Services params)
                            (Effect.map Main.Pages.Msg.Org__Repo__Build__Services >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Build__Services >> Page))
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

        Auth.Action.LoadCustomPage ->
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
                    , Maybe.Extra.unwrap
                        Cmd.none
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
                    , Maybe.Extra.unwrap
                        Cmd.none
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
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | Page Main.Pages.Msg.Msg
    | Layout Main.Layouts.Msg.Msg
    | Shared Shared.Msg
    | Batch (List Msg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested (Browser.Internal url) ->
            ( model
            , Browser.Navigation.pushUrl model.key (Url.toString url)
            )

        UrlRequested (Browser.External url) ->
            if String.isEmpty (String.trim url) then
                ( model, Cmd.none )

            else
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
        ( Main.Pages.Msg.Home_ pageMsg, Main.Pages.Model.Home_ pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Home_
                        (Effect.map Main.Pages.Msg.Home_ >> fromPageEffect model)
                        (Page.update (Pages.Home_.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Account_Authenticate pageMsg, Main.Pages.Model.Account_Authenticate pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.Account_Authenticate
                (Effect.map Main.Pages.Msg.Account_Authenticate >> fromPageEffect model)
                (Page.update (Pages.Account.Authenticate.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.Account_Login pageMsg, Main.Pages.Model.Account_Login pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.Account_Login
                (Effect.map Main.Pages.Msg.Account_Login >> fromPageEffect model)
                (Page.update (Pages.Account.Login.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.Account_Logout pageMsg, Main.Pages.Model.Account_Logout pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.Account_Logout
                (Effect.map Main.Pages.Msg.Account_Logout >> fromPageEffect model)
                (Page.update (Pages.Account.Logout.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.Account_Settings pageMsg, Main.Pages.Model.Account_Settings pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Account_Settings
                        (Effect.map Main.Pages.Msg.Account_Settings >> fromPageEffect model)
                        (Page.update (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Account_SourceRepos pageMsg, Main.Pages.Model.Account_SourceRepos pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Account_SourceRepos
                        (Effect.map Main.Pages.Msg.Account_SourceRepos >> fromPageEffect model)
                        (Page.update (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Admin_Settings pageMsg, Main.Pages.Model.Admin_Settings pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Admin_Settings
                        (Effect.map Main.Pages.Msg.Admin_Settings >> fromPageEffect model)
                        (Page.update (Pages.Admin.Settings.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dash_Secrets_Engine__Org_Org_ pageMsg, Main.Pages.Model.Dash_Secrets_Engine__Org_Org_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dash_Secrets_Engine__Org_Org_ params)
                        (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org_ >> fromPageEffect model)
                        (Page.update (Pages.Dash.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Add pageMsg, Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Add params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Add params)
                        (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Add >> fromPageEffect model)
                        (Page.update (Pages.Dash.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Name_ pageMsg, Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Name_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Name_ params)
                        (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Name_ >> fromPageEffect model)
                        (Page.update (Pages.Dash.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo_ pageMsg, Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo_ params)
                        (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo_ >> fromPageEffect model)
                        (Page.update (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Add pageMsg, Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Add params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Add params)
                        (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Add >> fromPageEffect model)
                        (Page.update (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Name_ pageMsg, Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Name_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Name_ params)
                        (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Name_ >> fromPageEffect model)
                        (Page.update (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team_ pageMsg, Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team_ params)
                        (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team_ >> fromPageEffect model)
                        (Page.update (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Add pageMsg, Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Add params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Add params)
                        (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Add >> fromPageEffect model)
                        (Page.update (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Name_ pageMsg, Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Name_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Name_ params)
                        (Effect.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Name_ >> fromPageEffect model)
                        (Page.update (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dashboards pageMsg, Main.Pages.Model.Dashboards pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Dashboards
                        (Effect.map Main.Pages.Msg.Dashboards >> fromPageEffect model)
                        (Page.update (Pages.Dashboards.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Dashboards_Dashboard_ pageMsg, Main.Pages.Model.Dashboards_Dashboard_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Dashboards_Dashboard_ params)
                        (Effect.map Main.Pages.Msg.Dashboards_Dashboard_ >> fromPageEffect model)
                        (Page.update (Pages.Dashboards.Dashboard_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Status_Workers pageMsg, Main.Pages.Model.Status_Workers pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Status_Workers
                        (Effect.map Main.Pages.Msg.Status_Workers >> fromPageEffect model)
                        (Page.update (Pages.Status.Workers.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
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

        ( Main.Pages.Msg.Org__Builds pageMsg, Main.Pages.Model.Org__Builds params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Builds params)
                        (Effect.map Main.Pages.Msg.Org__Builds >> fromPageEffect model)
                        (Page.update (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo_ pageMsg, Main.Pages.Model.Org__Repo_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo_ params)
                        (Effect.map Main.Pages.Msg.Org__Repo_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Deployments pageMsg, Main.Pages.Model.Org__Repo__Deployments params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Deployments params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Deployments >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Deployments_Add pageMsg, Main.Pages.Model.Org__Repo__Deployments_Add params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Deployments_Add params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Deployments_Add >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Deployments.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Hooks pageMsg, Main.Pages.Model.Org__Repo__Hooks params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Hooks params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Hooks >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Hooks.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Insights pageMsg, Main.Pages.Model.Org__Repo__Insights params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Insights params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Insights >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Insights.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Pulls pageMsg, Main.Pages.Model.Org__Repo__Pulls params pageModel ) ->
            Tuple.mapBoth
                (Main.Pages.Model.Org__Repo__Pulls params)
                (Effect.map Main.Pages.Msg.Org__Repo__Pulls >> fromPageEffect model)
                (Page.update (Pages.Org_.Repo_.Pulls.page model.shared (Route.fromUrl params model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.Org__Repo__Schedules pageMsg, Main.Pages.Model.Org__Repo__Schedules params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Schedules params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Schedules >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Schedules_Add pageMsg, Main.Pages.Model.Org__Repo__Schedules_Add params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Schedules_Add params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Schedules_Add >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Schedules.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Schedules_Name_ pageMsg, Main.Pages.Model.Org__Repo__Schedules_Name_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Schedules_Name_ params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Schedules_Name_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Schedules.Name_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Settings pageMsg, Main.Pages.Model.Org__Repo__Settings params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Settings params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Settings >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Settings.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Tags pageMsg, Main.Pages.Model.Org__Repo__Tags params pageModel ) ->
            Tuple.mapBoth
                (Main.Pages.Model.Org__Repo__Tags params)
                (Effect.map Main.Pages.Msg.Org__Repo__Tags >> fromPageEffect model)
                (Page.update (Pages.Org_.Repo_.Tags.page model.shared (Route.fromUrl params model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.Org__Repo__Build_ pageMsg, Main.Pages.Model.Org__Repo__Build_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Build_ params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Build_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Build__Graph pageMsg, Main.Pages.Model.Org__Repo__Build__Graph params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Build__Graph params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Build__Graph >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.Graph.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Build__Pipeline pageMsg, Main.Pages.Model.Org__Repo__Build__Pipeline params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Build__Pipeline params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Build__Pipeline >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.Pipeline.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org__Repo__Build__Services pageMsg, Main.Pages.Model.Org__Repo__Build__Services params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org__Repo__Build__Services params)
                        (Effect.map Main.Pages.Msg.Org__Repo__Build__Services >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.NotFound_ pageMsg, Main.Pages.Model.NotFound_ pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.NotFound_
                (Effect.map Main.Pages.Msg.NotFound_ >> fromPageEffect model)
                (Page.update (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

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

        ( Just (Layouts.Default_Admin props), Just (Main.Layouts.Model.Default_Admin layoutModel), Main.Layouts.Msg.Default layoutMsg ) ->
            let
                defaultProps =
                    Layouts.Default.Admin.layout props model.shared route
                        |> Layout.parentProps
            in
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Admin { layoutModel | default = newModel }))
                (Effect.map Main.Layouts.Msg.Default >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.layout defaultProps model.shared route) layoutMsg layoutModel.default)

        ( Just (Layouts.Default_Admin props), Just (Main.Layouts.Model.Default_Admin layoutModel), Main.Layouts.Msg.Default_Admin layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Admin { layoutModel | admin = newModel }))
                (Effect.map Main.Layouts.Msg.Default_Admin >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.Admin.layout props model.shared route) layoutMsg layoutModel.admin)

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
                (\newModel -> Just (Main.Layouts.Model.Default_Build { layoutModel | build = newModel }))
                (Effect.map Main.Layouts.Msg.Default_Build >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.Build.layout props model.shared route) layoutMsg layoutModel.build)

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

        _ ->
            ( model.layout
            , Cmd.none
            )


toLayoutFromPage : Model -> Maybe (Layouts.Layout Msg)
toLayoutFromPage model =
    case model.page of
        Main.Pages.Model.Home_ pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Home_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Home_ >> Page))

        Main.Pages.Model.Account_Authenticate pageModel ->
            Route.fromUrl () model.url
                |> Pages.Account.Authenticate.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_Authenticate >> Page))

        Main.Pages.Model.Account_Login pageModel ->
            Route.fromUrl () model.url
                |> Pages.Account.Login.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_Login >> Page))

        Main.Pages.Model.Account_Logout pageModel ->
            Route.fromUrl () model.url
                |> Pages.Account.Logout.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_Logout >> Page))

        Main.Pages.Model.Account_Settings pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Account.Settings.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_Settings >> Page))

        Main.Pages.Model.Account_SourceRepos pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Account.SourceRepos.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Account_SourceRepos >> Page))

        Main.Pages.Model.Admin_Settings pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Admin.Settings.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Admin_Settings >> Page))

        Main.Pages.Model.Dash_Secrets_Engine__Org_Org_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dash.Secrets.Engine_.Org.Org_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Org_Org_ >> Page))

        Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Add params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dash.Secrets.Engine_.Org.Org_.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Add >> Page))

        Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Name_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dash.Secrets.Engine_.Org.Org_.Name_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Name_ >> Page))

        Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo_ >> Page))

        Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Add params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Add >> Page))

        Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Name_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Name_ >> Page))

        Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team_ >> Page))

        Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Add params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Add >> Page))

        Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Name_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Name_ >> Page))

        Main.Pages.Model.Dashboards pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Dashboards.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dashboards >> Page))

        Main.Pages.Model.Dashboards_Dashboard_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Dashboards.Dashboard_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Dashboards_Dashboard_ >> Page))

        Main.Pages.Model.Status_Workers pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Status.Workers.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Status_Workers >> Page))

        Main.Pages.Model.Org_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_ >> Page))

        Main.Pages.Model.Org__Builds params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Builds.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Builds >> Page))

        Main.Pages.Model.Org__Repo_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo_ >> Page))

        Main.Pages.Model.Org__Repo__Deployments params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Deployments.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Deployments >> Page))

        Main.Pages.Model.Org__Repo__Deployments_Add params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Deployments.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Deployments_Add >> Page))

        Main.Pages.Model.Org__Repo__Hooks params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Hooks.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Hooks >> Page))

        Main.Pages.Model.Org__Repo__Insights params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Insights.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Insights >> Page))

        Main.Pages.Model.Org__Repo__Pulls params pageModel ->
            Route.fromUrl params model.url
                |> Pages.Org_.Repo_.Pulls.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Pulls >> Page))

        Main.Pages.Model.Org__Repo__Schedules params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Schedules.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Schedules >> Page))

        Main.Pages.Model.Org__Repo__Schedules_Add params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Schedules.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Schedules_Add >> Page))

        Main.Pages.Model.Org__Repo__Schedules_Name_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Schedules.Name_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Schedules_Name_ >> Page))

        Main.Pages.Model.Org__Repo__Settings params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Settings.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Settings >> Page))

        Main.Pages.Model.Org__Repo__Tags params pageModel ->
            Route.fromUrl params model.url
                |> Pages.Org_.Repo_.Tags.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Tags >> Page))

        Main.Pages.Model.Org__Repo__Build_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Build_ >> Page))

        Main.Pages.Model.Org__Repo__Build__Graph params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.Graph.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Build__Graph >> Page))

        Main.Pages.Model.Org__Repo__Build__Pipeline params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.Pipeline.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Build__Pipeline >> Page))

        Main.Pages.Model.Org__Repo__Build__Services params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.Services.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org__Repo__Build__Services >> Page))

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

        ( Auth.Action.LoadCustomPage, Auth.Action.LoadCustomPage ) ->
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
                Main.Pages.Model.Home_ pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Home_.page user model.shared (Route.fromUrl () model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Home_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Account_Authenticate pageModel ->
                    Page.subscriptions (Pages.Account.Authenticate.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.Account_Authenticate
                        |> Sub.map Page

                Main.Pages.Model.Account_Login pageModel ->
                    Page.subscriptions (Pages.Account.Login.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.Account_Login
                        |> Sub.map Page

                Main.Pages.Model.Account_Logout pageModel ->
                    Page.subscriptions (Pages.Account.Logout.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.Account_Logout
                        |> Sub.map Page

                Main.Pages.Model.Account_Settings pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Account_Settings
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Account_SourceRepos pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Account_SourceRepos
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Admin_Settings pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Admin.Settings.page user model.shared (Route.fromUrl () model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Admin_Settings
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dash_Secrets_Engine__Org_Org_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dash.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Add params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dash.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Add
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Name_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dash.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Name_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Add params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Add
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Name_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Name_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Add params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Add
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Name_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Name_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dashboards pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dashboards.page user model.shared (Route.fromUrl () model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dashboards
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Dashboards_Dashboard_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Dashboards.Dashboard_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Dashboards_Dashboard_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Status_Workers pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Status.Workers.page user model.shared (Route.fromUrl () model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Status_Workers
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Builds params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Builds
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Deployments params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Deployments
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Deployments_Add params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Deployments.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Deployments_Add
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Hooks params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Hooks.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Hooks
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Insights params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Insights.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Insights
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Pulls params pageModel ->
                    Page.subscriptions (Pages.Org_.Repo_.Pulls.page model.shared (Route.fromUrl params model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.Org__Repo__Pulls
                        |> Sub.map Page

                Main.Pages.Model.Org__Repo__Schedules params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Schedules
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Schedules_Add params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Schedules.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Schedules_Add
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Schedules_Name_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Schedules.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Schedules_Name_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Settings params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Settings.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Settings
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Tags params pageModel ->
                    Page.subscriptions (Pages.Org_.Repo_.Tags.page model.shared (Route.fromUrl params model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.Org__Repo__Tags
                        |> Sub.map Page

                Main.Pages.Model.Org__Repo__Build_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Build_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Build__Graph params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.Graph.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Build__Graph
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Build__Pipeline params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.Pipeline.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Build__Pipeline
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org__Repo__Build__Services params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org__Repo__Build__Services
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

                ( Just (Layouts.Default_Admin props), Just (Main.Layouts.Model.Default_Admin layoutModel) ) ->
                    let
                        defaultProps =
                            Layouts.Default.Admin.layout props model.shared route
                                |> Layout.parentProps
                    in
                    Sub.batch
                        [ Layout.subscriptions (Layouts.Default.layout defaultProps model.shared route) layoutModel.default
                            |> Sub.map Main.Layouts.Msg.Default
                            |> Sub.map Layout
                        , Layout.subscriptions (Layouts.Default.Admin.layout props model.shared route) layoutModel.admin
                            |> Sub.map Main.Layouts.Msg.Default_Admin
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
                        , Layout.subscriptions (Layouts.Default.Build.layout props model.shared route) layoutModel.build
                            |> Sub.map Main.Layouts.Msg.Default_Build
                            |> Sub.map Layout
                        ]

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

        ( Just (Layouts.Default_Admin props), Just (Main.Layouts.Model.Default_Admin layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Admin.layout props model.shared route
                        |> Layout.parentProps
            in
            Layout.view
                (Layouts.Default.layout defaultProps model.shared route)
                { model = layoutModel.default
                , toContentMsg = Main.Layouts.Msg.Default >> Layout
                , content =
                    Layout.view
                        (Layouts.Default.Admin.layout props model.shared route)
                        { model = layoutModel.admin
                        , toContentMsg = Main.Layouts.Msg.Default_Admin >> Layout
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
                        { model = layoutModel.build
                        , toContentMsg = Main.Layouts.Msg.Default_Build >> Layout
                        , content = viewPage model
                        }
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

        _ ->
            viewPage model


viewPage : Model -> View Msg
viewPage model =
    case model.page of
        Main.Pages.Model.Home_ pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Home_.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Home_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Account_Authenticate pageModel ->
            Page.view (Pages.Account.Authenticate.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.Account_Authenticate
                |> View.map Page

        Main.Pages.Model.Account_Login pageModel ->
            Page.view (Pages.Account.Login.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.Account_Login
                |> View.map Page

        Main.Pages.Model.Account_Logout pageModel ->
            Page.view (Pages.Account.Logout.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.Account_Logout
                |> View.map Page

        Main.Pages.Model.Account_Settings pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Account_Settings
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Account_SourceRepos pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Account_SourceRepos
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Admin_Settings pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Admin.Settings.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Admin_Settings
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Org_Org_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dash.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Add params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dash.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Add
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Name_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dash.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Name_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Add params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Add
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Name_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Name_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Add params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Add
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Name_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Name_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dashboards pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dashboards.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dashboards
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dashboards_Dashboard_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Dashboards.Dashboard_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Dashboards_Dashboard_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Status_Workers pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Status.Workers.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Status_Workers
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Builds params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Builds
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Deployments params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Deployments
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Deployments_Add params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Deployments.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Deployments_Add
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Hooks params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Hooks.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Hooks
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Insights params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Insights.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Insights
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Pulls params pageModel ->
            Page.view (Pages.Org_.Repo_.Pulls.page model.shared (Route.fromUrl params model.url)) pageModel
                |> View.map Main.Pages.Msg.Org__Repo__Pulls
                |> View.map Page

        Main.Pages.Model.Org__Repo__Schedules params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Schedules
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Schedules_Add params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Schedules.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Schedules_Add
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Schedules_Name_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Schedules.Name_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Schedules_Name_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Settings params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Settings.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Settings
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Tags params pageModel ->
            Page.view (Pages.Org_.Repo_.Tags.page model.shared (Route.fromUrl params model.url)) pageModel
                |> View.map Main.Pages.Msg.Org__Repo__Tags
                |> View.map Page

        Main.Pages.Model.Org__Repo__Build_ params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Build_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Build__Graph params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.Graph.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Build__Graph
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Build__Pipeline params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.Pipeline.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Build__Pipeline
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Build__Services params pageModel ->
            Auth.Action.view (View.map never (Auth.viewCustomPage model.shared (Route.fromUrl () model.url)))
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org__Repo__Build__Services
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
            Auth.viewCustomPage model.shared (Route.fromUrl () model.url)
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
        Main.Pages.Model.Home_ pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Home_.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Home_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Account_Authenticate pageModel ->
            Page.toUrlMessages routes (Pages.Account.Authenticate.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.Account_Authenticate
                |> List.map Page
                |> toCommands

        Main.Pages.Model.Account_Login pageModel ->
            Page.toUrlMessages routes (Pages.Account.Login.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.Account_Login
                |> List.map Page
                |> toCommands

        Main.Pages.Model.Account_Logout pageModel ->
            Page.toUrlMessages routes (Pages.Account.Logout.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.Account_Logout
                |> List.map Page
                |> toCommands

        Main.Pages.Model.Account_Settings pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Account_Settings
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Account_SourceRepos pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Account_SourceRepos
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Admin_Settings pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Admin.Settings.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Admin_Settings
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Org_Org_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dash.Secrets.Engine_.Org.Org_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Add params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dash.Secrets.Engine_.Org.Org_.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Add
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Org_Org__Name_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dash.Secrets.Engine_.Org.Org_.Name_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dash_Secrets_Engine__Org_Org__Name_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Add params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Add
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Repo_Org__Repo__Name_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dash_Secrets_Engine__Repo_Org__Repo__Name_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Add params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Add
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dash_Secrets_Engine__Shared_Org__Team__Name_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dash_Secrets_Engine__Shared_Org__Team__Name_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dashboards pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dashboards.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Dashboards
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Dashboards_Dashboard_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Dashboards.Dashboard_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Dashboards_Dashboard_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Status_Workers pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Status.Workers.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Status_Workers
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

        Main.Pages.Model.Org__Builds params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Builds
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Deployments params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Deployments
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Deployments_Add params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Deployments.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Deployments_Add
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Hooks params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Hooks.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Hooks
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Insights params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Insights.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Insights
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Pulls params pageModel ->
            Page.toUrlMessages routes (Pages.Org_.Repo_.Pulls.page model.shared (Route.fromUrl params model.url))
                |> List.map Main.Pages.Msg.Org__Repo__Pulls
                |> List.map Page
                |> toCommands

        Main.Pages.Model.Org__Repo__Schedules params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Schedules
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Schedules_Add params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Schedules.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Schedules_Add
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Schedules_Name_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Schedules.Name_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Schedules_Name_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Settings params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Settings.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Settings
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Tags params pageModel ->
            Page.toUrlMessages routes (Pages.Org_.Repo_.Tags.page model.shared (Route.fromUrl params model.url))
                |> List.map Main.Pages.Msg.Org__Repo__Tags
                |> List.map Page
                |> toCommands

        Main.Pages.Model.Org__Repo__Build_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Build_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Build__Graph params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.Graph.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Build__Graph
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Build__Pipeline params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.Pipeline.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Build__Pipeline
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org__Repo__Build__Services params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org__Repo__Build__Services
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.NotFound_ pageModel ->
            Page.toUrlMessages routes (Pages.NotFound_.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.NotFound_
                |> List.map Page
                |> toCommands

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

        ( Just (Layouts.Default_Admin props), Just (Main.Layouts.Model.Default_Admin layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Admin.layout props model.shared route
                        |> Layout.parentProps
            in
            Cmd.batch
                [ Layout.toUrlMessages routes (Layouts.Default.layout defaultProps model.shared route)
                    |> List.map Main.Layouts.Msg.Default
                    |> List.map Layout
                    |> toCommands
                , Layout.toUrlMessages routes (Layouts.Default.Admin.layout props model.shared route)
                    |> List.map Main.Layouts.Msg.Default_Admin
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

        _ ->
            Cmd.none


hasNavigatedWithinNewLayout : { from : Maybe (Layouts.Layout msg), to : Maybe (Layouts.Layout msg) } -> Bool
hasNavigatedWithinNewLayout { from, to } =
    let
        isRelated maybePair =
            case maybePair of
                Just ( Layouts.Default _, Layouts.Default _ ) ->
                    True

                Just ( Layouts.Default_Admin _, Layouts.Default_Admin _ ) ->
                    True

                Just ( Layouts.Default_Admin _, Layouts.Default _ ) ->
                    True

                Just ( Layouts.Default_Build _, Layouts.Default_Build _ ) ->
                    True

                Just ( Layouts.Default_Build _, Layouts.Default _ ) ->
                    True

                Just ( Layouts.Default_Org _, Layouts.Default_Org _ ) ->
                    True

                Just ( Layouts.Default_Org _, Layouts.Default _ ) ->
                    True

                Just ( Layouts.Default_Repo _, Layouts.Default_Repo _ ) ->
                    True

                Just ( Layouts.Default_Repo _, Layouts.Default _ ) ->
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
        Route.Path.Home_ ->
            True

        Route.Path.Account_Authenticate ->
            False

        Route.Path.Account_Login ->
            False

        Route.Path.Account_Logout ->
            False

        Route.Path.Account_Settings ->
            True

        Route.Path.Account_SourceRepos ->
            True

        Route.Path.Admin_Settings ->
            True

        Route.Path.Dash_Secrets_Engine__Org_Org_ _ ->
            True

        Route.Path.Dash_Secrets_Engine__Org_Org__Add _ ->
            True

        Route.Path.Dash_Secrets_Engine__Org_Org__Name_ _ ->
            True

        Route.Path.Dash_Secrets_Engine__Repo_Org__Repo_ _ ->
            True

        Route.Path.Dash_Secrets_Engine__Repo_Org__Repo__Add _ ->
            True

        Route.Path.Dash_Secrets_Engine__Repo_Org__Repo__Name_ _ ->
            True

        Route.Path.Dash_Secrets_Engine__Shared_Org__Team_ _ ->
            True

        Route.Path.Dash_Secrets_Engine__Shared_Org__Team__Add _ ->
            True

        Route.Path.Dash_Secrets_Engine__Shared_Org__Team__Name_ _ ->
            True

        Route.Path.Dashboards ->
            True

        Route.Path.Dashboards_Dashboard_ _ ->
            True

        Route.Path.Status_Workers ->
            True

        Route.Path.Org_ _ ->
            True

        Route.Path.Org__Builds _ ->
            True

        Route.Path.Org__Repo_ _ ->
            True

        Route.Path.Org__Repo__Deployments _ ->
            True

        Route.Path.Org__Repo__Deployments_Add _ ->
            True

        Route.Path.Org__Repo__Hooks _ ->
            True

        Route.Path.Org__Repo__Insights _ ->
            True

        Route.Path.Org__Repo__Pulls _ ->
            False

        Route.Path.Org__Repo__Schedules _ ->
            True

        Route.Path.Org__Repo__Schedules_Add _ ->
            True

        Route.Path.Org__Repo__Schedules_Name_ _ ->
            True

        Route.Path.Org__Repo__Settings _ ->
            True

        Route.Path.Org__Repo__Tags _ ->
            False

        Route.Path.Org__Repo__Build_ _ ->
            True

        Route.Path.Org__Repo__Build__Graph _ ->
            True

        Route.Path.Org__Repo__Build__Pipeline _ ->
            True

        Route.Path.Org__Repo__Build__Services _ ->
            True

        Route.Path.NotFound_ ->
            False
