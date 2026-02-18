/*
 * SPDX-License-Identifier: Apache-2.0
 */

import * as fs from 'fs';
import * as path from 'path';

const testDataRoot = path.resolve(__dirname, '..', 'test-data');

// Helper function to read test data from a JSON file in the test-data directory
export function readTestData<T = unknown>(dataName: string): T {
  const dataPath = path.join(testDataRoot, dataName);
  const raw = fs.readFileSync(dataPath, 'utf-8');
  return JSON.parse(raw) as T;
}
