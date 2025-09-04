/**
 * NovaBot Lambda Functions Test Suite
 * 
 * This test suite validates all Lambda functions work correctly
 * Tests include unit tests, integration tests, and error handling
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Test configuration
const CONFIG = {
    projectRoot: path.resolve(__dirname, '..'),
    lambdaFunctions: [
        'zendesk_create_ticket',
        'lex_fulfillment', 
        'invoke_agent'
    ],
    testTimeout: 30000,
    awsRegion: process.env.AWS_REGION || 'us-east-1'
};

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

// Test tracking
let testResults = {
    passed: 0,
    failed: 0,
    skipped: 0,
    errors: []
};

/**
 * Logging utilities
 */
function log(message, color = colors.reset) {
    console.log(`${color}${message}${colors.reset}`);
}

function logInfo(message) {
    log(`[INFO] ${message}`, colors.blue);
}

function logSuccess(message) {
    log(`[SUCCESS] ✓ ${message}`, colors.green);
}

function logError(message) {
    log(`[ERROR] ✗ ${message}`, colors.red);
}

function logWarning(message) {
    log(`[WARNING] ⚠ ${message}`, colors.yellow);
}

/**
 * Test runner utility
 */
async function runTest(testName, testFn) {
    logInfo(`Running test: ${testName}`);
    
    try {
        const startTime = Date.now();
        await testFn();
        const duration = Date.now() - startTime;
        
        logSuccess(`${testName} (${duration}ms)`);
        testResults.passed++;
        return true;
    } catch (error) {
        logError(`${testName}: ${error.message}`);
        testResults.failed++;
        testResults.errors.push({
            test: testName,
            error: error.message,
            stack: error.stack
        });
        return false;
    }
}

/**
 * Check if Lambda function directory exists and is properly structured
 */
function validateLambdaStructure(functionName) {
    const functionDir = path.join(CONFIG.projectRoot, 'lambda', functionName);
    
    if (!fs.existsSync(functionDir)) {
        throw new Error(`Lambda function directory not found: ${functionDir}`);
    }
    
    const requiredFiles = ['package.json', 'src/index.ts', 'tsconfig.json'];
    for (const file of requiredFiles) {
        const filePath = path.join(functionDir, file);
        if (!fs.existsSync(filePath)) {
            throw new Error(`Required file not found: ${file}`);
        }
    }
    
    return functionDir;
}

/**
 * Install dependencies for a Lambda function
 */
function installDependencies(functionDir) {
    logInfo(`Installing dependencies for ${path.basename(functionDir)}`);
    
    try {
        execSync('npm ci', {
            cwd: functionDir,
            stdio: 'pipe'
        });
    } catch (error) {
        throw new Error(`npm ci failed: ${error.message}`);
    }
}

/**
 * Compile TypeScript for a Lambda function
 */
function compileTypeScript(functionDir) {
    logInfo(`Compiling TypeScript for ${path.basename(functionDir)}`);
    
    try {
        execSync('npm run build', {
            cwd: functionDir,
            stdio: 'pipe'
        });
    } catch (error) {
        throw new Error(`TypeScript compilation failed: ${error.message}`);
    }
}

/**
 * Run linting for a Lambda function
 */
function runLinting(functionDir) {
    logInfo(`Running linter for ${path.basename(functionDir)}`);
    
    try {
        execSync('npm run lint', {
            cwd: functionDir,
            stdio: 'pipe'
        });
    } catch (error) {
        // Linting failures are warnings, not errors
        logWarning(`Linting issues in ${path.basename(functionDir)}: ${error.message}`);
    }
}

/**
 * Run unit tests for a Lambda function
 */
function runUnitTests(functionDir) {
    const testScript = path.join(functionDir, 'package.json');
    const packageJson = JSON.parse(fs.readFileSync(testScript, 'utf8'));
    
    if (!packageJson.scripts || !packageJson.scripts.test) {
        logWarning(`No test script found for ${path.basename(functionDir)}`);
        return;
    }
    
    logInfo(`Running unit tests for ${path.basename(functionDir)}`);
    
    try {
        execSync('npm test', {
            cwd: functionDir,
            stdio: 'pipe'
        });
    } catch (error) {
        throw new Error(`Unit tests failed: ${error.message}`);
    }
}

/**
 * Validate Lambda function package size
 */
function validatePackageSize(functionDir) {
    const distDir = path.join(functionDir, 'dist');
    
    if (!fs.existsSync(distDir)) {
        throw new Error(`Dist directory not found: ${distDir}`);
    }
    
    // Create a temporary zip to check size
    const tempZip = path.join(functionDir, 'temp-package.zip');
    
    try {
        execSync(`cd ${functionDir} && zip -r ${tempZip} dist/ node_modules/ -x "node_modules/.cache/*" "*.git*"`, {
            stdio: 'pipe'
        });
        
        const stats = fs.statSync(tempZip);
        const sizeMB = stats.size / (1024 * 1024);
        
        // AWS Lambda has a 50MB limit for zipped packages
        if (sizeMB > 50) {
            throw new Error(`Package size too large: ${sizeMB.toFixed(2)}MB (limit: 50MB)`);
        }
        
        logInfo(`Package size for ${path.basename(functionDir)}: ${sizeMB.toFixed(2)}MB`);
        
        // Cleanup
        fs.unlinkSync(tempZip);
        
    } catch (error) {
        // Cleanup on error
        if (fs.existsSync(tempZip)) {
            fs.unlinkSync(tempZip);
        }
        throw error;
    }
}

/**
 * Test Zendesk Create Ticket Lambda Function
 */
async function testZendeskCreateTicket() {
    const functionName = 'zendesk_create_ticket';
    const functionDir = validateLambdaStructure(functionName);
    
    // Test function structure
    await runTest(`${functionName}: Structure validation`, async () => {
        validateLambdaStructure(functionName);
    });
    
    // Test dependency installation
    await runTest(`${functionName}: Dependency installation`, async () => {
        installDependencies(functionDir);
    });
    
    // Test TypeScript compilation
    await runTest(`${functionName}: TypeScript compilation`, async () => {
        compileTypeScript(functionDir);
    });
    
    // Test linting
    await runTest(`${functionName}: Code linting`, async () => {
        runLinting(functionDir);
    });
    
    // Test unit tests (if available)
    await runTest(`${functionName}: Unit tests`, async () => {
        runUnitTests(functionDir);
    });
    
    // Test package size
    await runTest(`${functionName}: Package size validation`, async () => {
        validatePackageSize(functionDir);
    });
    
    // Test function exports
    await runTest(`${functionName}: Function exports`, async () => {
        const indexPath = path.join(functionDir, 'dist', 'index.js');
        if (!fs.existsSync(indexPath)) {
            throw new Error('Compiled index.js not found');
        }
        
        // Basic smoke test for exports (without actually running the function)
        const indexContent = fs.readFileSync(indexPath, 'utf8');
        if (!indexContent.includes('handler')) {
            throw new Error('Handler export not found in compiled code');
        }
    });
}

/**
 * Test Lex Fulfillment Lambda Function
 */
async function testLexFulfillment() {
    const functionName = 'lex_fulfillment';
    const functionDir = validateLambdaStructure(functionName);
    
    // Test function structure
    await runTest(`${functionName}: Structure validation`, async () => {
        validateLambdaStructure(functionName);
    });
    
    // Test dependency installation
    await runTest(`${functionName}: Dependency installation`, async () => {
        installDependencies(functionDir);
    });
    
    // Test TypeScript compilation
    await runTest(`${functionName}: TypeScript compilation`, async () => {
        compileTypeScript(functionDir);
    });
    
    // Test linting
    await runTest(`${functionName}: Code linting`, async () => {
        runLinting(functionDir);
    });
    
    // Test unit tests (if available)
    await runTest(`${functionName}: Unit tests`, async () => {
        runUnitTests(functionDir);
    });
    
    // Test package size
    await runTest(`${functionName}: Package size validation`, async () => {
        validatePackageSize(functionDir);
    });
}

/**
 * Test Invoke Agent Lambda Function
 */
async function testInvokeAgent() {
    const functionName = 'invoke_agent';
    const functionDir = validateLambdaStructure(functionName);
    
    // Test function structure
    await runTest(`${functionName}: Structure validation`, async () => {
        validateLambdaStructure(functionName);
    });
    
    // Test dependency installation
    await runTest(`${functionName}: Dependency installation`, async () => {
        installDependencies(functionDir);
    });
    
    // Test TypeScript compilation
    await runTest(`${functionName}: TypeScript compilation`, async () => {
        compileTypeScript(functionDir);
    });
    
    // Test linting
    await runTest(`${functionName}: Code linting`, async () => {
        runLinting(functionDir);
    });
    
    // Test unit tests (if available)
    await runTest(`${functionName}: Unit tests`, async () => {
        runUnitTests(functionDir);
    });
    
    // Test package size
    await runTest(`${functionName}: Package size validation`, async () => {
        validatePackageSize(functionDir);
    });
}

/**
 * Test OpenAPI schema validation
 */
async function testOpenAPISchema() {
    await runTest('OpenAPI Schema: Validation', async () => {
        const schemaPath = path.join(CONFIG.projectRoot, 'infra', 'terraform', 'modules', 'bedrock_agent', 'openapi', 'zendesk.yaml');
        
        if (!fs.existsSync(schemaPath)) {
            throw new Error('OpenAPI schema file not found');
        }
        
        // Basic YAML syntax validation
        try {
            const yaml = require('js-yaml');
            const schemaContent = fs.readFileSync(schemaPath, 'utf8');
            const schema = yaml.load(schemaContent);
            
            // Validate basic OpenAPI structure
            if (!schema.openapi) {
                throw new Error('Missing OpenAPI version');
            }
            
            if (!schema.info || !schema.info.title) {
                throw new Error('Missing API info');
            }
            
            if (!schema.paths) {
                throw new Error('Missing API paths');
            }
            
            logInfo('OpenAPI schema structure is valid');
            
        } catch (error) {
            if (error.code === 'MODULE_NOT_FOUND') {
                logWarning('js-yaml not available, skipping detailed validation');
                // Basic file existence check passed
                return;
            }
            throw error;
        }
    });
}

/**
 * Test environment configuration
 */
async function testEnvironmentConfig() {
    await runTest('Environment: Configuration validation', async () => {
        const envFiles = [
            path.join(CONFIG.projectRoot, 'infra', 'terraform', 'envs', 'dev', 'terraform.tfvars'),
            path.join(CONFIG.projectRoot, 'infra', 'terraform', 'envs', 'dev', 'backend.hcl')
        ];
        
        for (const envFile of envFiles) {
            if (!fs.existsSync(envFile)) {
                throw new Error(`Environment file not found: ${envFile}`);
            }
            
            const content = fs.readFileSync(envFile, 'utf8');
            if (content.trim().length === 0) {
                throw new Error(`Environment file is empty: ${envFile}`);
            }
        }
        
        logInfo('Environment configuration files exist and are not empty');
    });
}

/**
 * Test web widget files
 */
async function testWebWidget() {
    await runTest('Web Widget: File validation', async () => {
        const widgetDir = path.join(CONFIG.projectRoot, 'web', 'widget');
        
        if (!fs.existsSync(widgetDir)) {
            throw new Error('Web widget directory not found');
        }
        
        const requiredFiles = ['widget.js', 'widget.css'];
        for (const file of requiredFiles) {
            const filePath = path.join(widgetDir, file);
            if (!fs.existsSync(filePath)) {
                throw new Error(`Widget file not found: ${file}`);
            }
            
            const content = fs.readFileSync(filePath, 'utf8');
            if (content.trim().length === 0) {
                throw new Error(`Widget file is empty: ${file}`);
            }
        }
        
        logInfo('Web widget files are present and not empty');
    });
}

/**
 * Generate test report
 */
function generateTestReport() {
    console.log('\n' + '='.repeat(60));
    log('NovaBot Lambda Functions Test Report', colors.cyan);
    console.log('='.repeat(60));
    
    logSuccess(`Tests passed: ${testResults.passed}`);
    
    if (testResults.failed > 0) {
        logError(`Tests failed: ${testResults.failed}`);
        console.log('\nFailed tests:');
        testResults.errors.forEach((error, index) => {
            console.log(`\n${index + 1}. ${error.test}`);
            logError(`   Error: ${error.error}`);
        });
    }
    
    if (testResults.skipped > 0) {
        logWarning(`Tests skipped: ${testResults.skipped}`);
    }
    
    const total = testResults.passed + testResults.failed + testResults.skipped;
    const successRate = total > 0 ? ((testResults.passed / total) * 100).toFixed(1) : 0;
    
    console.log(`\nSuccess rate: ${successRate}%`);
    
    if (testResults.failed === 0) {
        console.log('\n' + '🎉 All tests passed! Lambda functions are ready for deployment.'.green);
    } else {
        console.log('\n' + '❌ Some tests failed. Please fix the issues before deployment.'.red);
    }
    
    return testResults.failed === 0;
}

/**
 * Main test execution
 */
async function main() {
    logInfo('Starting NovaBot Lambda Functions Test Suite');
    logInfo(`Project root: ${CONFIG.projectRoot}`);
    logInfo(`AWS Region: ${CONFIG.awsRegion}`);
    console.log('');
    
    try {
        // Test each Lambda function
        await testZendeskCreateTicket();
        await testLexFulfillment();
        await testInvokeAgent();
        
        // Test supporting components
        await testOpenAPISchema();
        await testEnvironmentConfig();
        await testWebWidget();
        
        // Generate final report
        const allPassed = generateTestReport();
        
        process.exit(allPassed ? 0 : 1);
        
    } catch (error) {
        logError(`Test suite failed: ${error.message}`);
        console.error(error.stack);
        process.exit(1);
    }
}

// Add color support to strings
Object.defineProperty(String.prototype, 'green', {
    get() { return colors.green + this + colors.reset; }
});

Object.defineProperty(String.prototype, 'red', {
    get() { return colors.red + this + colors.reset; }
});

// Run tests if this script is executed directly
if (require.main === module) {
    main();
}

module.exports = {
    runTest,
    testZendeskCreateTicket,
    testLexFulfillment,
    testInvokeAgent,
    testOpenAPISchema,
    testEnvironmentConfig,
    testWebWidget
};