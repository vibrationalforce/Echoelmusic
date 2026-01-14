/**
 * CoherenceCore Jest Configuration
 *
 * Monorepo test configuration for frequency-engine and evm-engine packages.
 */

module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/packages'],
  testMatch: ['**/*.test.ts'],
  moduleNameMapper: {
    '^@coherence-core/shared-types$': '<rootDir>/packages/shared-types/src/index.ts',
    '^@coherence-core/frequency-engine$': '<rootDir>/packages/frequency-engine/src/index.ts',
    '^@coherence-core/evm-engine$': '<rootDir>/packages/evm-engine/src/index.ts',
  },
  transform: {
    '^.+\\.tsx?$': ['ts-jest', {
      tsconfig: {
        target: 'ES2020',
        module: 'CommonJS',
        moduleResolution: 'node',
        lib: ['ES2020', 'DOM'],
        esModuleInterop: true,
        strict: true,
        skipLibCheck: true,
      },
    }],
  },
  collectCoverageFrom: [
    'packages/*/src/**/*.ts',
    '!packages/*/src/**/*.test.ts',
    '!packages/*/src/**/*.d.ts',
  ],
  coverageReporters: ['text', 'lcov', 'html'],
  coverageDirectory: 'coverage',
  verbose: true,
};
