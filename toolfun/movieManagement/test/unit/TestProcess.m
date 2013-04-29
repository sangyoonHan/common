classdef TestProcess < TestCase
    
    properties
        movie
        process
    end
    
    methods
        function self = TestProcess(name)
            self = self@TestCase(name);
        end
        
        %% Set up and tear down methods
        function setUp(self)
            self.movie = MovieData();
            self.process = MockProcess(self.movie);
            self.movie.addProcess(self.process);
        end
        
        function tearDown(self)
            delete(self.movie);
            delete(self.process);
        end
        
        %% Tests
        function testGetProcess(self)
            assertEqual(self.movie.getProcess(1), self.process);
        end
        
        
        function testGetSingleProcessIndex(self)
            iProc = self.movie.getProcessIndex(self.process);
            assertEqual(iProc, 1);
        end
        
        function testGetMultipleProcessIndex(self)
            process2 = MockProcess(self.movie);
            self.movie.addProcess(process2);
            iProc = self.movie.getProcessIndex(process2, Inf);
            assertEqual(iProc, [1 2]);
        end
        
        function testDeleteProcess(self)
            % Delete process and test deletion
            self.movie.deleteProcess(1);
            assertTrue(isempty(self.movie.processes_));
        end
        
        function testDeleteInvalidProcess(self)
            % Delete process object
            delete(self.process);
            assertFalse(self.movie.getProcess(1).isvalid);
            
            % Delete process using deleteProcess method
            self.movie.deleteProcess(1);
            assertTrue(isempty(self.movie.processes_));
        end
        
        function testReplaceProcess(self)
            process2 = MockProcess(self.movie);
            self.movie.replaceProcess(1, process2);
            
            % Replace process
            assertEqual(self.movie.getProcess(1), process2);
            assertFalse(self.process.isvalid);
        end
    end
end