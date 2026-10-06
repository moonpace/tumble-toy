#!/usr/bin/env node

import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { readFile, writeFile } from "node:fs/promises";

const token = process.env.PIXELLAB_API_KEY || process.env.PIXELLAB_TOKEN;
if (!token) {
  console.error("Set PIXELLAB_API_KEY or PIXELLAB_TOKEN in the local process.");
  process.exit(2);
}

const child = spawn(
  "npx",
  [
    "mcp-remote@latest",
    "https://api.pixellab.ai/mcp",
    "--transport",
    "http-only",
    "--header",
    "Authorization:${AUTH_HEADER}",
  ],
  {
    env: { ...process.env, AUTH_HEADER: `Bearer ${token}` },
    stdio: ["pipe", "pipe", "inherit"],
  },
);

const requests = new Map();
let nextId = 1;
function notify(method, params = {}) {
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
}
function request(method, params = {}) {
  const id = nextId++;
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
  return new Promise((resolve, reject) => requests.set(id, { resolve, reject }));
}

const lines = createInterface({ input: child.stdout });
lines.on("line", (line) => {
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    return;
  }
  if (message.id && requests.has(message.id)) {
    const pending = requests.get(message.id);
    requests.delete(message.id);
    if (message.error) pending.reject(new Error(JSON.stringify(message.error)));
    else pending.resolve(message.result);
  }
});

const timeout = setTimeout(() => {
  console.error("PixelLab MCP request timed out.");
  child.kill();
  process.exit(1);
}, 60000);

try {
  const initialized = await request("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "tumble-toy-resource-pipeline", version: "1.0.0" },
  });
  notify("notifications/initialized");
  const mode = process.argv[2] || "list";
  if (mode === "list") {
    const toolList = await request("tools/list");
    await writeFile(
      "artifacts/pixellab-mcp-tools.json",
      `${JSON.stringify({ initialized, tools: toolList.tools }, null, 2)}\n`,
      "utf8",
    );
    console.log(`PixelLab MCP initialized; ${toolList.tools.length} tools recorded.`);
    for (const tool of toolList.tools) console.log(tool.name);
  } else if (mode === "call") {
    const [, , , toolName, argumentsPath, outputPath] = process.argv;
    if (!toolName || !argumentsPath || !outputPath) {
      throw new Error("Usage: pixellab_mcp_client.mjs call TOOL ARGUMENTS_JSON OUTPUT_JSON");
    }
    const toolArguments = JSON.parse(await readFile(argumentsPath, "utf8"));
    const result = await request("tools/call", { name: toolName, arguments: toolArguments });
    await writeFile(outputPath, `${JSON.stringify(result, null, 2)}\n`, "utf8");
    const text = (result.content || []).filter((item) => item.type === "text").map((item) => item.text).join("\n");
    console.log(text.slice(0, 2000) || `${toolName} completed; result written to ${outputPath}`);
  } else if (mode === "generate") {
    const [, , , assetId, outputPath] = process.argv;
    if (!assetId || !outputPath) {
      throw new Error("Usage: pixellab_mcp_client.mjs generate ASSET_ID OUTPUT_JSON");
    }
    const manifest = JSON.parse(await readFile("docs/pixellab-generation-prompts.json", "utf8"));
    const asset = manifest.assets.find((item) => item.id === assetId);
    if (!asset) throw new Error(`Unknown PixelLab asset ID: ${assetId}`);
    const requestSize = asset.request_size || asset.size;
    const toolArguments = {
      description: `${manifest.common_prompt} ${asset.prompt}`,
      width: requestSize[0],
      height: requestSize[1],
      no_background: asset.no_background,
      isometric: asset.isometric,
      outline: "single color outline",
      shading: "flat shading",
      detail: "low detail",
      text_guidance_scale: 15,
      seed: asset.seed,
    };
    if (asset.init_image) {
      toolArguments.init_image_base64 = (await readFile(asset.init_image)).toString("base64");
      toolArguments.init_image_strength = asset.init_image_strength;
    }
    const palettePath = "artifacts/pixellab-init-guides/palette.png";
    toolArguments.color_image_base64 = (await readFile(palettePath)).toString("base64");
    const result = await request("tools/call", { name: "create_image_pixflux", arguments: toolArguments });
    await writeFile(outputPath, `${JSON.stringify(result, null, 2)}\n`, "utf8");
    const text = (result.content || []).filter((item) => item.type === "text").map((item) => item.text).join("\n");
    console.log(text.slice(0, 2000) || `create_image_pixflux completed; result written to ${outputPath}`);
  } else if (mode === "get") {
    const [, , , assetId, createResultPath, imageOutputPath, metadataOutputPath] = process.argv;
    if (!assetId || !createResultPath || !imageOutputPath || !metadataOutputPath) {
      throw new Error("Usage: pixellab_mcp_client.mjs get ASSET_ID CREATE_JSON OUTPUT_PNG METADATA_JSON");
    }
    const created = JSON.parse(await readFile(createResultPath, "utf8"));
    const createdText = (created.content || []).filter((item) => item.type === "text").map((item) => item.text).join("\n");
    const jobMatch = createdText.match(/job_id:\s*([0-9a-f-]+)/i);
    if (!jobMatch) throw new Error(`No job_id found in ${createResultPath}`);
    const result = await request("tools/call", { name: "get_image", arguments: { job_id: jobMatch[1] } });
    const imageItem = (result.content || []).find((item) => item.type === "image");
    const textItems = (result.content || []).filter((item) => item.type === "text");
    let imageData = imageItem?.data;
    if (!imageData) {
      const text = textItems.map((item) => item.text).join("\n");
      const url = text.match(/https:\/\/[^\s)]+/i)?.[0];
      if (url && !/status:\s*(pending|processing)/i.test(text)) {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`Image download failed: HTTP ${response.status}`);
        imageData = Buffer.from(await response.arrayBuffer()).toString("base64");
      }
    }
    const metadata = {
      asset_id: assetId,
      job_id: jobMatch[1],
      is_error: result.isError || false,
      text: textItems.map((item) => item.text).join("\n"),
      mime_type: imageItem?.mimeType || "image/png",
      received_image: Boolean(imageData),
    };
    await writeFile(metadataOutputPath, `${JSON.stringify(metadata, null, 2)}\n`, "utf8");
    if (!imageData) {
      console.log(metadata.text.slice(0, 2000));
      process.exitCode = 3;
    } else {
      await writeFile(imageOutputPath, Buffer.from(imageData, "base64"));
      console.log(`Downloaded ${assetId} from PixelLab MCP job ${jobMatch[1]}`);
    }
  } else if (mode === "batch-get") {
    const assetIds = process.argv.slice(3);
    if (!assetIds.length) throw new Error("Usage: pixellab_mcp_client.mjs batch-get ASSET_ID...");
    let missing = 0;
    for (const assetId of assetIds) {
      const createResultPath = `artifacts/pixellab-mcp-results/${assetId}-create.json`;
      const created = JSON.parse(await readFile(createResultPath, "utf8"));
      const createdText = (created.content || []).filter((item) => item.type === "text").map((item) => item.text).join("\n");
      const jobMatch = createdText.match(/job_id:\s*([0-9a-f-]+)/i);
      if (!jobMatch) throw new Error(`No job_id found in ${createResultPath}`);
      const result = await request("tools/call", { name: "get_image", arguments: { job_id: jobMatch[1] } });
      const imageItem = (result.content || []).find((item) => item.type === "image");
      const textItems = (result.content || []).filter((item) => item.type === "text");
      const text = textItems.map((item) => item.text).join("\n");
      let imageData = imageItem?.data;
      if (!imageData) {
        const url = text.match(/https:\/\/[^\s)]+/i)?.[0];
        if (url && !/status:\s*(pending|processing)/i.test(text)) {
          const response = await fetch(url);
          if (response.ok) imageData = Buffer.from(await response.arrayBuffer()).toString("base64");
        }
      }
      await writeFile(
        `artifacts/pixellab-mcp-results/${assetId}-get.json`,
        `${JSON.stringify({ asset_id: assetId, job_id: jobMatch[1], is_error: result.isError || false, text, mime_type: imageItem?.mimeType || "image/png", received_image: Boolean(imageData) }, null, 2)}\n`,
        "utf8",
      );
      if (imageData) {
        await writeFile(`artifacts/pixellab-mcp-results/${assetId}.png`, Buffer.from(imageData, "base64"));
        console.log(`Downloaded ${assetId}`);
      } else {
        missing += 1;
        console.log(`Pending ${assetId}`);
      }
    }
    if (missing) process.exitCode = 3;
  } else {
    throw new Error(`Unknown mode: ${mode}`);
  }
  clearTimeout(timeout);
  child.kill();
} catch (error) {
  clearTimeout(timeout);
  console.error(error.message);
  child.kill();
  process.exit(1);
}
