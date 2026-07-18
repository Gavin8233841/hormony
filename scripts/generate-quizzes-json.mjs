#!/usr/bin/env node
/**
 * 保留既有题库生成入口；统一生成器会同时刷新题库及其依赖的课程内容资产，
 * 防止新增学科只更新一份平行 JSON。
 */

import { generateLearningContent } from "./generate-learning-content.mjs";

generateLearningContent();
