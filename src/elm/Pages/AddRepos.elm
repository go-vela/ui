{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.AddRepos exposing (view)

import Dict
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , details
        , div
        , h1
        , p
        , span
        , summary
        , text
        )
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import Search
    exposing
        ( filterRepo
        , repoSearchBarGlobal
        , repoSearchBarLocal
        , searchFilterGlobal
        , searchFilterLocal
        , shouldSearch
        )
import Svg.Attributes
import SvgBuilder
import Util
import Vela
    exposing
        ( ActivateRepo
        , ActivateRepos
        , AddRepo
        , FavoritesModel
        , Org
        , RepoSearchFilters
        , Repositories
        , Repository
        , Search
        , SourceRepositories
        , repoFavorited
        )


{-| view : takes model and renders account page for activating repos to overview
-}
view : WebData SourceRepositories -> FavoritesModel -> RepoSearchFilters -> Search msg -> ActivateRepo msg -> ActivateRepos msg -> AddRepo msg -> Html msg
view sourceRepos favorites sourceSearchFilters search activateRepo activateRepos addRepo =
    let
        loading =
            div []
                [ h1 []
                    [ text "Loading your Repositories"
                    , span [ class "loading-ellipsis" ] []
                    ]
                , p []
                    [ text <|
                        "Hang tight while we grab the list of repositories that you have access to from Github. If you have access to "
                            ++ "a lot of organizations and repositories this might take a little while."
                    ]
                ]
    in
    case sourceRepos of
        RemoteData.Success repos ->
            div [ class "source-repos", Util.testAttribute "source-repos" ]
                [ repoSearchBarGlobal sourceSearchFilters search
                , viewSourceRepos repos favorites sourceSearchFilters search activateRepo activateRepos addRepo
                ]

        RemoteData.Loading ->
            loading

        RemoteData.NotAsked ->
            loading

        RemoteData.Failure _ ->
            div []
                [ p []
                    [ text <|
                        "There was an error fetching your available repositories... Click Refresh or try again later!"
                    ]
                ]


{-| viewSourceRepos : takes model and source repos and renders them based on user search
-}
viewSourceRepos : SourceRepositories -> FavoritesModel -> RepoSearchFilters -> Search msg -> ActivateRepo msg -> ActivateRepos msg -> AddRepo msg -> Html msg
viewSourceRepos sourceRepos favorites sourceSearchFilters search activateRepo activateRepos addRepo =
    if shouldSearch <| searchFilterGlobal sourceSearchFilters then
        -- Search and render repos using the global filter
        searchReposGlobal favorites sourceSearchFilters sourceRepos activateRepo addRepo

    else
        -- Render repos normally
        sourceRepos
            |> Dict.toList
            |> Util.filterEmptyLists
            |> List.map (\( org, repos_ ) -> viewSourceOrg favorites sourceSearchFilters org repos_ search activateRepo activateRepos addRepo)
            |> div [ class "repo-list" ]


{-| viewSourceOrg : renders the source repositories available to a user by org
-}
viewSourceOrg : FavoritesModel -> RepoSearchFilters -> Org -> Repositories -> Search msg -> ActivateRepo msg -> ActivateRepos msg -> AddRepo msg -> Html msg
viewSourceOrg favorites sourceSearchFilters org repos search activateRepo activateRepos addRepo =
    let
        ( repos_, filtered, content ) =
            if shouldSearch <| searchFilterLocal org sourceSearchFilters then
                -- Search and render repos using the global filter
                searchReposLocal favorites org sourceSearchFilters repos activateRepo addRepo

            else
                -- Render repos normally
                ( repos, False, List.map (viewSourceRepo favorites activateRepo addRepo) repos )
    in
    viewSourceOrgDetails sourceSearchFilters org repos_ filtered content search activateRepos


{-| viewSourceOrgDetails : renders the source repositories by org as an html details element
-}
viewSourceOrgDetails : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> ActivateRepos msg -> Html msg
viewSourceOrgDetails sourceSearchFilters org repos filtered content search activateRepos =
    div [ class "org" ]
        [ details [ class "details", class "repo-item" ] <|
            viewSourceOrgSummary sourceSearchFilters org repos filtered content search activateRepos
        ]


{-| viewSourceOrgSummary : renders the source repositories details summary
-}
viewSourceOrgSummary : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> ActivateRepos msg -> List (Html msg)
viewSourceOrgSummary sourceSearchFilters org repos filtered content search activateRepos =
    summary [ class "summary", Util.testAttribute <| "source-org-" ++ org ]
        [ div [ class "org-header" ]
            [ text org
            , viewRepoCount repos
            ]
        ]
        :: div [ class "source-actions" ]
            [ repoSearchBarLocal sourceSearchFilters org search
            , activateReposBtn org repos filtered activateRepos
            ]
        :: content


{-| viewSourceRepo : renders single repo within a list of org repos

    viewSourceRepo uses model.SourceRepositories and buildAddRepoElement to determine the state of each specific 'Add' button

-}
viewSourceRepo : FavoritesModel -> ActivateRepo msg -> AddRepo msg -> Repository -> Html msg
viewSourceRepo favoritesModel activateRepo addRepo repo =
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div [] [ text repo.name ]
        , div []
            [ SvgBuilder.favoritesStar [ Svg.Attributes.class "-cursor", onClick <| addRepo repo.org repo.name ] <| repoFavorited repo.org repo.name favoritesModel
            , buildActivateRepoElement repo activateRepo
            ]
        ]


{-| viewSearchedSourceRepo : renders single repo when searching across all repos
-}
viewSearchedSourceRepo : FavoritesModel -> ActivateRepo msg -> AddRepo msg -> Repository -> Html msg
viewSearchedSourceRepo favoritesModel activateRepo addRepo repo =
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div []
            [ text <| repo.org ++ "/" ++ repo.name ]
        , div
            []
            [ SvgBuilder.favoritesStar [ Svg.Attributes.class "-cursor", onClick <| addRepo repo.org repo.name ] <| repoFavorited repo.org repo.name favoritesModel
            , buildActivateRepoElement repo activateRepo
            ]
        ]


{-| viewRepoCount : renders the amount of repos available within an org
-}
viewRepoCount : List a -> Html msg
viewRepoCount repos =
    span [ class "repo-count", Util.testAttribute "source-repo-count" ] [ code [] [ text <| (String.fromInt <| List.length repos) ++ " repos" ] ]


{-| activateReposBtn : takes List of repos and renders a button to add them all at once, texts depends on user input filter
-}
activateReposBtn : Org -> Repositories -> Bool -> ActivateRepos msg -> Html msg
activateReposBtn org repos filtered activateRepos =
    button [ class "-inverted", Util.testAttribute <| "add-org-" ++ org, onClick (activateRepos repos) ]
        [ text <|
            if filtered then
                "Add Results"

            else
                "Add All"
        ]


{-| buildActivateRepoElement : builds action element for activating a single repo
-}
buildActivateRepoElement : Repository -> ActivateRepo msg -> Html msg
buildActivateRepoElement repo activateRepo =
    case repo.added of
        RemoteData.NotAsked ->
            button [ class "-solid", onClick (activateRepo repo) ] [ text "Activate" ]

        RemoteData.Loading ->
            div [ class "repo-activate--activating" ] [ span [ class "repo-activate--activating-text" ] [ text "Activating" ], span [ class "loading-ellipsis" ] [] ]

        RemoteData.Failure _ ->
            div [ class "repo-activate--failed", onClick (activateRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]

        RemoteData.Success addedStatus ->
            if addedStatus then
                div [ class "-added-container" ]
                    [ div [ class "repo-activate--added" ] [ FeatherIcons.check |> FeatherIcons.toHtml [ attribute "role" "img" ], span [] [ text "Added" ] ]
                    , a [ class "-btn", class "-solid", class "-view", Routes.href <| Routes.RepositoryBuilds repo.org repo.name Nothing Nothing ] [ text "View" ]
                    ]

            else
                div [ class "repo-activate--failed", onClick (activateRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]


{-| searchReposGlobal : takes source repositories and search filters and renders filtered repos
-}
searchReposGlobal : FavoritesModel -> RepoSearchFilters -> SourceRepositories -> ActivateRepo msg -> AddRepo msg -> Html msg
searchReposGlobal favoritesModel filters repos activateRepo addRepo =
    let
        filteredRepos =
            repos
                |> Dict.toList
                |> Util.filterEmptyLists
                |> List.map (\( _, repos_ ) -> repos_)
                |> List.concat
                |> List.filter (\repo -> filterRepo filters Nothing <| repo.org ++ "/" ++ repo.name)
    in
    div [ class "filtered-repos" ] <|
        -- Render the found repositories
        if not <| List.isEmpty filteredRepos then
            filteredRepos |> List.map (\repo -> viewSearchedSourceRepo favoritesModel activateRepo addRepo repo)

        else
            -- No repos matched the search
            [ div [ class "-no-repos" ] [ text "No results" ] ]


{-| searchReposLocal : takes repo search filters, the org, and repos and renders a list of repos based on user-entered text
-}
searchReposLocal : FavoritesModel -> Org -> RepoSearchFilters -> Repositories -> ActivateRepo msg -> AddRepo msg -> ( Repositories, Bool, List (Html msg) )
searchReposLocal favoritesModel org filters repos activateRepo addRepo =
    -- Filter the repos if the user typed more than 2 characters
    let
        filteredRepos =
            List.filter (\repo -> filterRepo filters (Just org) repo.name) repos
    in
    ( filteredRepos
    , True
    , if not <| List.isEmpty filteredRepos then
        List.map (viewSourceRepo favoritesModel activateRepo addRepo) filteredRepos

      else
        [ div [ class "-no-repos" ] [ text "No results" ] ]
    )
