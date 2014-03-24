classdef TestProcess < TestLibrary
    
    properties
        process
    end
    
    methods
        %% Set up and tear down methods
        function setUp(self)
            self.process = self.setUpProcess();
        end
        
        % Basic tests
        function testIsProcess(self)
            assertTrue(Process.isProcess(class(self.process)));
            assertFalse(Process.isProcess('InvalidProcessClass'));
        end
        
        %% Get functions
        function testGetProcess(self)
            assertEqual(self.movie.getProcess(1), self.process);
        end
        
        function testGetProcessIndexByObject(self)
            assertEqual(self.movie.getProcessIndex(self.process), 1);
        end
        
        function testGetProcessIndexByName(self)
            assertEqual(self.movie.getProcessIndex(class(self.process)), 1);
        end
        
        function testGetProcessIndexMultiple(self)
            self.setUpProcess();
            assertEqual(self.movie.getProcessIndex(self.process, Inf), [1 2]);
        end
        
        function testGetOwner(self)
            assertEqual(self.process.getOwner(), self.movie);
        end
        
        %% Parameters test
        function testGetParameters(self)
            assertEqual(self.process.getParameters(), self.process.funParams_);
        end
        
        function testSetParametersSame(self)
            defaultParameters = MockProcess.getDefaultParams(self.movie);
            self.process.setParameters(defaultParameters);
            assertEqual(self.process.funParams_, defaultParameters);
            assertFalse(self.process.procChanged_);
        end
        
        function testSetParametersNew(self)
            newParameters = MockProcess.getDefaultParams(self.movie);
            newParameters.MockParam1 = false;
            self.process.setParameters(newParameters);
            assertEqual(self.process.funParams_, newParameters);
            assertTrue(self.process.procChanged_);
        end
        
        function testSetParaSame(self)
            defaultParameters = MockProcess.getDefaultParams(self.movie);
            self.process.setPara(defaultParameters);
            assertEqual(self.process.funParams_, defaultParameters);
            assertFalse(self.process.procChanged_);
        end
        
        function testSetParaNew(self)
            newParameters = MockProcess.getDefaultParams(self.movie);
            newParameters.MockParam1 = false;
            self.process.setPara(newParameters);
            assertEqual(self.process.funParams_, newParameters);
            assertTrue(self.process.procChanged_);
        end
        
        function testSanityCheckDefaults(self)
            parameters = MockProcess.getDefaultParams(self.movie);
            self.process.sanityCheck();
            assertEqual(self.process.funParams_, parameters);
        end
        
        function testSanityCheckNonDefaults(self)
            process2 = MockProcess(self.movie, struct('MockParam3', false));
            assertEqual(process2.funParams_, struct('MockParam3', false));
            process2.sanityCheck();
            parameters = MockProcess.getDefaultParams(self.movie);
            parameters.MockParam3 = false;
            assertEqual(process2.funParams_, parameters);
        end
        
        %% deleteProcess tests
        function testDeleteProcessByIndex(self)
            % Test process deletion by index
            self.movie.deleteProcess(1);
            assertTrue(isempty(self.movie.processes_));
        end
        
        function testDeleteProcessByObject(self)
            % Test process deletion by object
            self.movie.deleteProcess(self.process);
            assertTrue(isempty(self.movie.processes_));
        end
        
        function testDeleteSameClassProcessByIndex(self)
            % Duplicate process class and test deletion by index
            process2 = self.setUpProcess();
            self.movie.deleteProcess(1);
            assertEqual(self.movie.processes_, {process2});
        end
        
        function testDeleteSameClassProcessByObject(self)
            % Duplicate process class and test deletion by object
            process2 = self.setUpProcess();
            self.movie.deleteProcess(self.process);
            assertEqual(self.movie.processes_, {process2});
        end
        
        function testDeletePackageLinkedProcessByIndex(self)
            % Link process to package and test deletion by index
            
            package = self.setUpPackage();
            package.setProcess(1, self.process);
            self.movie.deleteProcess(1);
            assertTrue(isempty(self.movie.processes_));
            assertTrue(isempty(package.getProcess(1)));
        end
        
        function testDeletePackageLinkedProcessByObject(self)
            % Link process to package and test deletion by object
            
            package = self.setUpPackage();
            package.setProcess(1, self.process);
            self.movie.deleteProcess(self.process);
            assertTrue(isempty(self.movie.processes_));
            assertTrue(isempty(package.getProcess(1)));
        end
        
        function testDeleteMultiPackageLinkedProcessByIndex(self)
            % Link process to package and test deletion by index
            
            package1 = self.setUpPackage();
            package2 = self.setUpPackage();
            package1.setProcess(1, self.process);
            package2.setProcess(1, self.process);
            self.movie.deleteProcess(self.process);
            assertTrue(isempty(self.movie.processes_));
            assertTrue(isempty(package1.getProcess(1)));
            assertTrue(isempty(package2.getProcess(1)));
        end
        
        function testDeleteMultiPackageLinkedProcessByObject(self)
            % Link process to package and test deletion by index
            
            package1 = self.setUpPackage();
            package2 = self.setUpPackage();
            package1.setProcess(1, self.process);
            package2.setProcess(1, self.process);
            self.movie.deleteProcess(self.process);
            assertTrue(isempty(self.movie.processes_));
            assertTrue(isempty(package1.getProcess(1)));
            assertTrue(isempty(package2.getProcess(1)));
        end
        
        function testDeleteUnlinkedProcess(self)
            % Delete process and test deletion
            f= @() self.movie.deleteProcess(MockProcess(self.movie));
            assertExceptionThrown(f ,'');
        end
        
        function testDeleteInvalidProcessByIndex(self)
            % Delete process object
            delete(self.process);
            assertFalse(self.movie.getProcess(1).isvalid);
            
            % Delete process using deleteProcess method
            self.movie.deleteProcess(1);
            assertTrue(isempty(self.movie.processes_));
        end
        
        function testGetPackageUnlinked(self)
            % Test getPackage method for unlinked process
            [packageID, processID] = self.process.getPackage();
            assertTrue(isempty(packageID));
            assertTrue(isempty(processID));
        end
        
        function testGetPackageLinked(self)
            % Link process to package and test getPackage method
            package = self.setUpPackage();
            package.setProcess(1, self.process);
            [packageID, processID] = self.process.getPackage();
            assertEqual(packageID, 1);
            assertEqual(processID, 1);
        end
        
        function testGetPackageMultilinked(self)
            % Link process to multiple package and test getPackage method
            package1 = self.setUpPackage();
            self.setUpPackage();
            package3 = self.setUpPackage();
            package1.setProcess(1, self.process);
            package3.setProcess(1, self.process);
            [packageID, processID] = self.process.getPackage();
            assertEqual(packageID, [1 3]);
            assertEqual(processID, [1 1]);
        end
        %% ReplaceProcess
        function testReplaceProcessByIndex(self)
            process2 = MockProcess(self.movie);
            self.movie.replaceProcess(1, process2);
            
            % Replace process
            assertEqual(self.movie.getProcess(1), process2);
            assertFalse(self.process.isvalid);
        end
        
        function testReplaceProcessByObject(self)
            process2 = MockProcess(self.movie);
            self.movie.replaceProcess(self.process, process2);
            
            % Replace process
            assertEqual(self.movie.getProcess(1), process2);
            assertFalse(self.process.isvalid);
        end
        
        %% Process methods
        function testGetPackageUnshared(self)
            assertTrue(isempty(self.process.getPackage()));
        end
        
        function getPackageSingle(self)
            package = self.setUpPackage();
            package.setProcess(1, self.process);
            assertEqual(self.process.getPackage(), 1);
        end
        
        function testGetPackageMultiple(self)
            for i = 1 :4
                package = self.setUpPackage();
                package.setProcess(1, self.process);
            end
            assertEqual(self.process.getPackage(), 1:4);
        end
        
        function testGetIndex(self)
            process2 = self.setUpProcess();
            assertEqual(self.process.getIndex(), 1);
            assertEqual(process2.getIndex(), 2);
        end
        
        %% Display method tests
        function testGetDisplayMethod1(self)
            assertTrue(isempty(self.process.getDisplayMethod(1, 1)));
            assertTrue(isempty(self.process.getDisplayMethod(1, 2)));
        end
        
        function testGetDisplayMethod2(self)
            displayMethod = LineDisplay();
            self.process.displayMethod_{1, 2} = displayMethod;
            assertTrue(isempty(self.process.getDisplayMethod(1, 1)));
            assertEqual(self.process.getDisplayMethod(1, 2), displayMethod);
            assertTrue(isempty(self.process.getDisplayMethod(2, 1)));
        end
        
        function testSetDisplayMethod(self)
            displayMethod = LineDisplay();
            self.process.setDisplayMethod(1, 2, displayMethod);
            assertEqual(self.process.displayMethod_{1, 2}, displayMethod);
            assertTrue(isempty(self.process.displayMethod_{1, 1}));
        end
        
        function testSetDisplayMethodExisting(self)
            displayMethod = LineDisplay();
            displayMethod2 = LineDisplay();
            self.process.setDisplayMethod(1, 2, displayMethod);
            self.process.setDisplayMethod(1, 2, displayMethod2);
            assertEqual(self.process.displayMethod_{1, 2}, displayMethod2);
            assertFalse(isvalid(displayMethod));
        end
    end
end
