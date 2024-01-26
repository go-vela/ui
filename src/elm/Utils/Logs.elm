{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Logs exposing (..)

import RemoteData exposing (WebData)
import Utils.Helpers as Util
import Vela


{-| topTrackerFocusId : takes resource number and returns the line focus id for auto focusing on log follow
-}
topTrackerFocusId : String -> String
topTrackerFocusId number =
    number ++ "-line-tracker-top"


{-| bottomTrackerFocusId : takes resource number and returns the line focus id for auto focusing on log follow
-}
bottomTrackerFocusId : String -> String
bottomTrackerFocusId number =
    number ++ "-line-tracker-bottom"


{-| safeDecodeLogData : takes log and decodes the data if it exists and does not exceed the size limit.
-}
safeDecodeLogData : Int -> Vela.Log -> Maybe (WebData Vela.Log) -> Maybe (WebData Vela.Log)
safeDecodeLogData sizeLimitBytes inLog inExistingLog =
    let
        existingLog =
            inExistingLog
                |> Maybe.withDefault RemoteData.NotAsked
                |> RemoteData.unwrap { rawData = "", decodedLogs = "" }
                    (\l -> { rawData = l.rawData, decodedLogs = l.decodedLogs })

        decoded =
            if inLog.size == 0 then
                "The build has not written anything to this log yet."

            else if inLog.size > sizeLimitBytes then
                "The data for this log exceeds the size limit of "
                    ++ Util.formatFilesize sizeLimitBytes
                    ++ ".\n"
                    ++ "To view this log use the CLI or click the 'download' link in the top right corner (downloading may take a few moments, depending on the size of the file)."

            else if inLog.rawData == existingLog.rawData then
                existingLog.decodedLogs

            else
                Util.base64Decode inLog.rawData
    in
    Just <| RemoteData.succeed { inLog | decodedLogs = decoded }
