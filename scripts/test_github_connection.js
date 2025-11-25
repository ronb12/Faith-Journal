#!/usr/bin/env node

/**
 * Test GitHub API Connection
 * 
 * This script tests your GitHub API connection and creates a test issue
 * to verify the Zapier integration will work.
 * 
 * Usage:
 *   node scripts/test_github_connection.js
 * 
 * Requires GITHUB_TOKEN environment variable
 */

const https = require('https');

const GITHUB_OWNER = 'ronb12';
const GITHUB_REPO = 'Faith-Journal';
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;

if (!GITHUB_TOKEN) {
  console.error('❌ GITHUB_TOKEN environment variable not set');
  console.error('');
  console.error('To create a GitHub token:');
  console.error('1. Go to https://github.com/settings/tokens');
  console.error('2. Click "Generate new token (classic)"');
  console.error('3. Select "repo" scope');
  console.error('4. Copy the token');
  console.error('5. Run: export GITHUB_TOKEN=your_token_here');
  console.error('6. Then run this script again');
  process.exit(1);
}

async function createTestIssue() {
  const issueData = {
    title: '[TEST] Support Email Integration Test',
    body: `## Test Issue from Setup Script

This is a test issue to verify the GitHub API connection works.

**From:** Setup Script
**Date:** ${new Date().toISOString()}

This issue can be deleted after verifying the Zapier integration works.

---
*This is a test issue created by the setup script.*`,
    labels: ['support', 'email', 'test']
  };

  const options = {
    hostname: 'api.github.com',
    path: `/repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues`,
    method: 'POST',
    headers: {
      'Authorization': `token ${GITHUB_TOKEN}`,
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
      'User-Agent': 'Faith-Journal-Setup-Script'
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          const issue = JSON.parse(data);
          resolve(issue);
        } else {
          reject(new Error(`GitHub API error: ${res.statusCode} - ${data}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.write(JSON.stringify(issueData));
    req.end();
  });
}

async function testConnection() {
  console.log('==========================================');
  console.log('GitHub API Connection Test');
  console.log('==========================================');
  console.log('');
  console.log(`Repository: ${GITHUB_OWNER}/${GITHUB_REPO}`);
  console.log('');

  try {
    console.log('Creating test issue...');
    const issue = await createTestIssue();
    
    console.log('✅ Success! Test issue created');
    console.log('');
    console.log(`Issue #${issue.number}: ${issue.title}`);
    console.log(`URL: ${issue.html_url}`);
    console.log('');
    console.log('You can delete this test issue after verifying Zapier works.');
    console.log('');
    console.log('Next steps:');
    console.log('1. Set up Zapier integration (see docs/ZAPIER_EMAIL_TO_GITHUB_SETUP.md)');
    console.log('2. Test by sending email to support@faithjournal.app');
    console.log('3. Verify issue is created automatically');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('');
    console.error('Troubleshooting:');
    console.error('1. Verify GITHUB_TOKEN is correct');
    console.error('2. Check token has "repo" scope');
    console.error('3. Verify repository name is correct');
    console.error('4. Check you have write access to the repository');
    process.exit(1);
  }
}

testConnection();

